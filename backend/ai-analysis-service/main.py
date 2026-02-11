"""
AI Analysis Service - FastAPI Microservice
Analyzes customer reviews for sentiment and topic extraction.
"""

import os
from datetime import datetime
from typing import Optional
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from nltk.sentiment import SentimentIntensityAnalyzer
import nltk

# Initialize FastAPI app
app = FastAPI(title="AI Analysis Service", version="0.1.0")

# Configure NLTK to use /tmp for data
nltk.data.path.append('/tmp/nltk_data')

# Download VADER lexicon on startup to /tmp
try:
    nltk.data.find('vader_lexicon')
except LookupError:
    nltk.download('vader_lexicon', download_dir='/tmp/nltk_data')

# Initialize VADER sentiment analyzer
sia = SentimentIntensityAnalyzer()


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
# SENTIMENT ANALYSIS
# ============================================================================

def analyze_sentiment(text: str) -> dict:
    """
    Analyze sentiment of review text using VADER.
    Returns sentiment label and compound score.
    
    Sentiment classification:
    - positive: compound >= 0.05
    - negative: compound <= -0.05
    - neutral: -0.05 < compound < 0.05
    """
    scores = sia.polarity_scores(text)
    compound = scores['compound']
    
    # Classify sentiment based on compound score
    if compound >= 0.05:
        sentiment = "positive"
    elif compound <= -0.05:
        sentiment = "negative"
    else:
        sentiment = "neutral"
    
    return {
        "sentiment": sentiment,
        "score": round(compound, 3),
        "details": {
            "positive": round(scores['pos'], 3),
            "negative": round(scores['neg'], 3),
            "neutral": round(scores['neu'], 3),
        }
    }


# ============================================================================
# TOPIC EXTRACTION
# ============================================================================

def extract_topics(text: str, rating: Optional[int] = None) -> list:
    """
    Extract topics/problems from review text.
    Uses keyword matching and sentiment indicators.
    """
    topics = []
    text_lower = text.lower()
    
    # Define keyword patterns for common topics
    topic_keywords = {
        "performance": ["fast", "slow", "speed", "lag", "crash", "freeze", "responsive"],
        "quality": ["quality", "durability", "build", "material", "solid", "fragile", "flimsy"],
        "battery": ["battery", "charge", "charging", "power", "endurance", "drain"],
        "connectivity": ["disconnect", "connection", "wifi", "bluetooth", "signal", "lag"],
        "design": ["design", "aesthetic", "look", "appearance", "rgb", "color", "style"],
        "price": ["price", "expensive", "cost", "cheap", "afford", "overpriced", "value"],
        "comfort": ["comfortable", "ergonomic", "pain", "fatigue", "typing", "click"],
        "customer_support": ["support", "customer service", "return", "warranty", "refund"],
        "heat_noise": ["hot", "heat", "warm", "noisy", "sound", "loud", "click", "noise"],
        "display": ["display", "screen", "color", "brightness", "bleed", "pixel", "resolution"],
    }
    
    # Match keywords to text
    for topic, keywords in topic_keywords.items():
        if any(keyword in text_lower for keyword in keywords):
            topics.append(topic)
    
    # Infer topics from rating if available
    if rating and rating <= 2:
        topics.append("negative_experience")
    elif rating and rating == 5:
        topics.append("highly_satisfied")
    
    return list(set(topics))  # Remove duplicates


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
