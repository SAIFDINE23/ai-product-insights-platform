"""
AI Analysis Service - FastAPI Microservice
Analyzes customer reviews for sentiment and topic extraction using Google Gemini API.
"""

import os
from datetime import datetime
from typing import Optional
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
import json

# Initialize FastAPI app
app = FastAPI(title="AI Analysis Service", version="0.1.0")

# Initialize Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY environment variable not set")

genai.configure(api_key=GEMINI_API_KEY)
MODEL_NAME = "gemini-2.0-flash"


# ============================================================================
# DATABASE CONNECTION
# ============================================================================

def get_db_connection():
    """Establish PostgreSQL connection using environment variables."""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            database=os.getenv("DB_NAME", "product_insights"),
            user=os.getenv("DB_USER", "app_user"),
            password=os.getenv("DB_PASSWORD", "app_password"),
        )
        return conn
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


def create_analyses_table(conn):
    """Create the reviews_analysis table if it doesn't exist."""
    query = """
    CREATE TABLE IF NOT EXISTS reviews_analysis (
        id SERIAL PRIMARY KEY,
        review_id INTEGER NOT NULL,
        sentiment VARCHAR(20) NOT NULL,
        sentiment_score FLOAT NOT NULL,
        topics TEXT,
        analyzed_at TIMESTAMP DEFAULT NOW(),
        FOREIGN KEY (review_id) REFERENCES reviews(id)
    );
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query)
        conn.commit()
    except psycopg2.Error as e:
        conn.rollback()
        print(f"Warning: Could not create table: {e}")


# ============================================================================
# SENTIMENT ANALYSIS WITH GEMINI
# ============================================================================

def analyze_sentiment(text: str) -> dict:
    """
    Analyze sentiment of review text using Google Gemini API.
    Returns sentiment label and detailed score.
    """
    prompt = f"""Analyze the sentiment of this review and provide a structured JSON response.

Review: {text}

Provide response in this exact JSON format:
{{
    "sentiment": "positive|negative|neutral",
    "score": <number from -1.0 to 1.0>,
    "confidence": <number from 0 to 1>,
    "summary": "<brief explanation of sentiment>"
}}

Only return valid JSON, no additional text."""
    
    try:
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        
        # Parse JSON response
        response_text = response.text.strip()
        # Clean up response if wrapped in markdown
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        
        result = json.loads(response_text.strip())
        
        return {
            "sentiment": result.get("sentiment", "neutral").lower(),
            "score": round(float(result.get("score", 0)), 3),
            "confidence": round(float(result.get("confidence", 0)), 3),
            "summary": result.get("summary", ""),
            "details": {
                "positive": 1.0 if result.get("sentiment", "").lower() == "positive" else 0,
                "negative": 1.0 if result.get("sentiment", "").lower() == "negative" else 0,
                "neutral": 1.0 if result.get("sentiment", "").lower() == "neutral" else 0,
            }
        }
    except Exception as e:
        print(f"Error analyzing sentiment with Gemini: {e}")
        # Fallback: simple heuristic analysis
        text_lower = text.lower()
        positive_words = ["great", "excellent", "amazing", "love", "perfect", "wonderful", "outstanding"]
        negative_words = ["bad", "terrible", "hate", "awful", "horrible", "poor", "useless"]
        
        pos_count = sum(1 for word in positive_words if word in text_lower)
        neg_count = sum(1 for word in negative_words if word in text_lower)
        
        if pos_count > neg_count:
            sentiment = "positive"
            score = 0.5
        elif neg_count > pos_count:
            sentiment = "negative"
            score = -0.5
        else:
            sentiment = "neutral"
            score = 0
        
        return {
            "sentiment": sentiment,
            "score": score,
            "confidence": 0.5,
            "summary": "Fallback analysis due to API error",
            "details": {
                "positive": 1.0 if sentiment == "positive" else 0,
                "negative": 1.0 if sentiment == "negative" else 0,
                "neutral": 1.0 if sentiment == "neutral" else 0,
            }
        }


# ============================================================================
# TOPIC EXTRACTION WITH GEMINI
# ============================================================================

def extract_topics(text: str, rating: Optional[int] = None) -> list:
    """
    Extract topics/problems from review text using Google Gemini API.
    Returns list of relevant topics found in the review.
    """
    prompt = f"""Extract key topics and issues mentioned in this review. Return a JSON array of topic names.

Review: {text}
Rating: {rating if rating else 'Not provided'}/5

Possible topics to identify: performance, quality, battery, connectivity, design, price, comfort, customer_support, heat_noise, display, installation, packaging, accessibility, software, reliability, compatibility

Return response as a valid JSON array of strings (topic names only):
["topic1", "topic2", ...]

Only return the JSON array, no additional text."""
    
    try:
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        
        # Parse JSON response
        response_text = response.text.strip()
        # Clean up response if wrapped in markdown
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        
        topics = json.loads(response_text.strip())
        
        # Add rating-based topics
        if rating and rating <= 2:
            topics.append("negative_experience")
        elif rating and rating == 5:
            topics.append("highly_satisfied")
        
        return list(set(topics))  # Remove duplicates
    except Exception as e:
        print(f"Error extracting topics with Gemini: {e}")
        # Fallback: keyword matching
        topics = []
        text_lower = text.lower()
        
        topic_keywords = {
            "performance": ["fast", "slow", "speed", "lag", "crash", "freeze", "responsive"],
            "quality": ["quality", "durability", "build", "material", "solid", "fragile"],
            "battery": ["battery", "charge", "charging", "power", "drain"],
            "connectivity": ["disconnect", "connection", "wifi", "bluetooth", "signal"],
            "design": ["design", "aesthetic", "look", "appearance", "color", "style"],
            "price": ["price", "expensive", "cost", "cheap", "afford", "value"],
            "comfort": ["comfortable", "ergonomic", "pain", "fatigue", "typing"],
            "customer_support": ["support", "customer service", "return", "warranty"],
            "heat_noise": ["hot", "heat", "noisy", "sound", "loud"],
            "display": ["display", "screen", "color", "brightness", "resolution"],
        }
        
        for topic, keywords in topic_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                topics.append(topic)
        
        if rating and rating <= 2:
            topics.append("negative_experience")
        elif rating and rating == 5:
            topics.append("highly_satisfied")
        
        return list(set(topics))


# ============================================================================
# PYDANTIC MODELS
# ============================================================================

class AnalysisRequest(BaseModel):
    """Request model for single review analysis."""
    review_text: str
    rating: Optional[int] = None


class AnalysisResponse(BaseModel):
    """Response model for analysis result."""
    sentiment: str
    sentiment_score: float
    topics: list
    details: dict


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.on_event("startup")
def startup_event():
    """Initialize database on startup."""
    try:
        conn = get_db_connection()
        create_analyses_table(conn)
        conn.close()
        print("✅ AI Analysis Service initialized")
    except Exception as e:
        print(f"⚠️ Startup warning: {e}")


@app.get("/health")
def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "ai-analysis-service",
        "version": "0.1.0",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.post("/analyze", response_model=AnalysisResponse)
def analyze_review(request: AnalysisRequest):
    """
    Analyze a single review for sentiment and topics.
    
    Input:
    - review_text: The review text to analyze
    - rating: Optional rating (1-5) to help with topic extraction
    
    Output:
    - sentiment: positive, negative, or neutral
    - sentiment_score: VADER compound score (-1 to 1)
    - topics: List of detected topics
    - details: Breakdown of sentiment scores (positive, negative, neutral)
    """
    # Analyze sentiment
    sentiment_result = analyze_sentiment(request.review_text)
    
    # Extract topics
    topics = extract_topics(request.review_text, request.rating)
    
    return AnalysisResponse(
        sentiment=sentiment_result["sentiment"],
        sentiment_score=sentiment_result["score"],
        topics=topics,
        details=sentiment_result["details"]
    )


@app.get("/analyze/reviews/all")
def analyze_all_reviews():
    """
    Analyze all reviews from database and store results.
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Get all unanalyzed reviews
            cur.execute("""
                SELECT r.id, r.review_text, r.rating 
                FROM reviews r
                LEFT JOIN reviews_analysis ra ON r.id = ra.review_id
                WHERE ra.id IS NULL
                LIMIT 100
            """)
            reviews = cur.fetchall()
        
        analyzed_count = 0
        for review in reviews:
            # Analyze review
            sentiment_result = analyze_sentiment(review['review_text'])
            topics = extract_topics(review['review_text'], review['rating'])
            
            # Store in database
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO reviews_analysis (review_id, sentiment, sentiment_score, topics)
                    VALUES (%s, %s, %s, %s)
                """, (
                    review['id'],
                    sentiment_result['sentiment'],
                    sentiment_result['score'],
                    ','.join(topics)
                ))
            analyzed_count += 1
        
        conn.commit()
        return {
            "status": "success",
            "reviews_analyzed": analyzed_count,
            "message": f"Analyzed {analyzed_count} reviews"
        }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/stats/sentiment")
def get_sentiment_stats():
    """
    Get sentiment distribution statistics from analyzed reviews.
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT sentiment, COUNT(*) as count, ROUND(AVG(sentiment_score)::numeric, 3) as avg_score
                FROM reviews_analysis
                GROUP BY sentiment
            """)
            stats = cur.fetchall()
        
        return {
            "sentiment_distribution": [dict(row) for row in stats],
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/stats/topics")
def get_topic_stats():
    """
    Get topic frequency from analyzed reviews.
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT topics FROM reviews_analysis WHERE topics IS NOT NULL")
            results = cur.fetchall()
        
        # Count topic frequencies
        topic_counts = {}
        for row in results:
            if row['topics']:
                topics = row['topics'].split(',')
                for topic in topics:
                    topic = topic.strip()
                    topic_counts[topic] = topic_counts.get(topic, 0) + 1
        
        # Sort by frequency
        sorted_topics = sorted(topic_counts.items(), key=lambda x: x[1], reverse=True)
        
        return {
            "top_topics": [{'topic': topic, 'count': count} for topic, count in sorted_topics],
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
