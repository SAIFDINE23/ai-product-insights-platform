# AI Analysis Service Documentation

## Overview

The **AI Analysis Service** is a FastAPI microservice that analyzes customer reviews for:
- **Sentiment** (positive, negative, neutral) using VADER
- **Topics** (performance, quality, battery, etc.) via keyword extraction

---

## Architecture

### Technology Stack
- **Framework**: FastAPI
- **Sentiment Analysis**: NLTK VADER
- **Topic Extraction**: Keyword matching
- **Database**: PostgreSQL
- **Language**: Python 3.11

### Tables Used
- `reviews` - Input reviews from scraper
- `reviews_analysis` - Analysis results (sentiment + topics)

---

## API Endpoints

### 1. Health Check
```http
GET /health
```

**Response**:
```json
{
  "status": "ok",
  "service": "ai-analysis-service",
  "version": "0.1.0",
  "timestamp": "2024-01-15T10:30:45.123456"
}
```

---

### 2. Analyze Single Review
```http
POST /analyze
Content-Type: application/json

{
  "review_text": "Great product! Very happy with it.",
  "rating": 5
}
```

**Response**:
```json
{
  "sentiment": "positive",
  "sentiment_score": 0.812,
  "topics": ["highly_satisfied", "quality"],
  "details": {
    "positive": 0.616,
    "negative": 0.0,
    "neutral": 0.384
  }
}
```

**Response Fields**:
- `sentiment`: "positive", "negative", or "neutral"
- `sentiment_score`: VADER compound score (-1 to 1)
  - >= 0.05 → positive
  - <= -0.05 → negative
  - between → neutral
- `topics`: List of detected topics
- `details`: Breakdown of VADER scores

---

### 3. Analyze All Reviews in DB
```http
GET /analyze/reviews/all
```

**Response**:
```json
{
  "status": "success",
  "reviews_analyzed": 100,
  "message": "Analyzed 100 reviews"
}
```

Analyzes all unanalyzed reviews from the database and stores results in `reviews_analysis` table.

---

### 4. Get Sentiment Statistics
```http
GET /stats/sentiment
```

**Response**:
```json
{
  "sentiment_distribution": [
    {
      "sentiment": "positive",
      "count": 55,
      "avg_score": 0.654
    },
    {
      "sentiment": "neutral",
      "count": 20,
      "avg_score": 0.015
    },
    {
      "sentiment": "negative",
      "count": 25,
      "avg_score": -0.487
    }
  ],
  "timestamp": "2024-01-15T10:30:45.123456"
}
```

---

### 5. Get Topic Statistics
```http
GET /stats/topics
```

**Response**:
```json
{
  "top_topics": [
    {"topic": "quality", "count": 45},
    {"topic": "design", "count": 38},
    {"topic": "price", "count": 32},
    {"topic": "performance", "count": 28},
    {"topic": "battery", "count": 12}
  ],
  "timestamp": "2024-01-15T10:30:45.123456"
}
```

---

## Sentiment Analysis (VADER)

### Scoring

VADER (Valence Aware Dictionary and sEntiment Reasoner) produces:
- `compound`: Normalized score between -1 (most negative) and +1 (most positive)

### Classification

```python
if compound >= 0.05:
    sentiment = "positive"
elif compound <= -0.05:
    sentiment = "negative"
else:
    sentiment = "neutral"
```

### Examples

| Review | Score | Sentiment | Reason |
|--------|-------|-----------|--------|
| "Excellent! Love it!" | 0.845 | positive | Strong positive words |
| "Good quality product" | 0.312 | positive | Mild positive words |
| "It's okay" | -0.015 | neutral | No sentiment indicators |
| "Poor quality, disappointed" | -0.656 | negative | Strong negative words |
| "Hate this, broken immediately" | -0.898 | negative | Very strong negative |

---

## Topic Extraction

### Detected Topics

| Topic | Keywords | Example |
|-------|----------|---------|
| performance | fast, slow, speed, lag, crash, freeze | "Very slow and crashes often" |
| quality | quality, durability, build, material | "Build quality is poor" |
| battery | battery, charge, power, drain | "Battery dies too quickly" |
| connectivity | disconnect, connection, wifi, bluetooth | "Keeps disconnecting from wifi" |
| design | design, aesthetic, rgb, color | "Love the RGB design" |
| price | price, expensive, cost, value | "Way too expensive" |
| comfort | comfortable, ergonomic, pain | "Hurts my wrist after hours of use" |
| customer_support | support, warranty, refund | "Support was unhelpful" |
| heat_noise | hot, noisy, loud, sound | "Gets very hot and loud" |
| display | display, screen, brightness, resolution | "Amazing display quality" |

### Special Topics

- `negative_experience`: Auto-added for ratings ≤ 2
- `highly_satisfied`: Auto-added for ratings = 5

---

## Testing

### Using curl

```bash
# Test health
curl http://localhost:8002/health

# Test analyze endpoint
curl -X POST http://localhost:8002/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Great product!",
    "rating": 5
  }'

# Analyze all reviews in DB
curl http://localhost:8002/analyze/reviews/all

# Get sentiment stats
curl http://localhost:8002/stats/sentiment

# Get topic stats
curl http://localhost:8002/stats/topics
```

### Using Python

```bash
# Install requests
pip install requests

# Run test suite
python scripts/test_ai_analysis.py
```

### Using bash script

```bash
chmod +x scripts/test_ai_analysis.sh
./scripts/test_ai_analysis.sh
```

---

## Database Schema

### reviews_analysis Table

```sql
CREATE TABLE reviews_analysis (
    id SERIAL PRIMARY KEY,
    review_id INTEGER NOT NULL,
    sentiment VARCHAR(20) NOT NULL,
    sentiment_score FLOAT NOT NULL,
    topics TEXT,
    analyzed_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (review_id) REFERENCES reviews(id)
);
```

### Example Query

```sql
-- Get all analyses with original reviews
SELECT 
    r.id,
    r.product_name,
    r.review_text,
    r.rating,
    ra.sentiment,
    ra.sentiment_score,
    ra.topics
FROM reviews r
JOIN reviews_analysis ra ON r.id = ra.review_id
ORDER BY ra.analyzed_at DESC;
```

---

## Environment Variables

```bash
DB_HOST=postgres              # PostgreSQL host
DB_PORT=5432                  # PostgreSQL port
DB_NAME=product_insights      # Database name
DB_USER=app_user              # Database user
DB_PASSWORD=app_password      # Database password
```

---

## Future Enhancements

1. **LLM Integration** (Gemini, GPT-4)
   - Planned: Via `ENABLE_LLM` environment variable
   - More nuanced sentiment and topic extraction

2. **Custom Sentiment Models**
   - Fine-tuned models for specific domains

3. **Multi-language Support**
   - Detect and analyze reviews in multiple languages

4. **Advanced Topic Extraction**
   - Aspect-based sentiment analysis
   - Named entity recognition for product components

---

## Troubleshooting

### Service won't start
- Check PostgreSQL connection: `docker compose ps`
- Verify environment variables
- Check logs: `docker logs ai-analysis-service`

### Analysis returns unexpected results
- VADER is rule-based, not ML-based
- Sarcasm and irony may not be detected correctly
- Consider LLM integration for complex reviews

### Topics not detected
- Keywords list might need expansion
- Consider using more advanced NLP (spaCy, transformers)

---

## Performance

- Single review analysis: ~10ms
- Database batch analysis: ~50ms per review
- Sentiment stats query: ~5ms
- Topic stats query: ~10ms (depends on data size)

---

## References

- [VADER Sentiment Analysis](https://github.com/cjhutto/vaderSentiment)
- [NLTK Documentation](https://www.nltk.org/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
