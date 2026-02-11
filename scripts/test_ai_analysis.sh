#!/bin/bash
# Test script for AI Analysis Service

API_URL="http://localhost:8002"

echo "======================================"
echo "AI Analysis Service - Test Suite"
echo "======================================"
echo ""

# Test 1: Health check
echo "1️⃣ Health Check"
echo "---"
curl -s -X GET "${API_URL}/health" | python3 -m json.tool
echo ""
echo ""

# Test 2: Analyze single positive review
echo "2️⃣ Analyze Positive Review"
echo "---"
curl -s -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Excellent laptop! Fast processor and great display quality. Highly recommend!",
    "rating": 5
  }' | python3 -m json.tool
echo ""
echo ""

# Test 3: Analyze single negative review
echo "3️⃣ Analyze Negative Review"
echo "---"
curl -s -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Broke after 2 weeks of normal use. Very disappointed and frustrated.",
    "rating": 1
  }' | python3 -m json.tool
echo ""
echo ""

# Test 4: Analyze neutral review
echo "4️⃣ Analyze Neutral Review"
echo "---"
curl -s -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "The product works as expected. Nothing special but does the job.",
    "rating": 3
  }' | python3 -m json.tool
echo ""
echo ""

# Test 5: Analyze review with specific issues
echo "5️⃣ Analyze Review with Performance Issues"
echo "---"
curl -s -X POST "${API_URL}/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Battery life is disappointing. The device gets hot during normal use and disconnects frequently.",
    "rating": 2
  }' | python3 -m json.tool
echo ""
echo ""

# Test 6: Analyze all reviews from DB
echo "6️⃣ Analyze All Reviews from Database"
echo "---"
curl -s -X GET "${API_URL}/analyze/reviews/all" | python3 -m json.tool
echo ""
echo ""

# Test 7: Get sentiment statistics
echo "7️⃣ Get Sentiment Statistics"
echo "---"
curl -s -X GET "${API_URL}/stats/sentiment" | python3 -m json.tool
echo ""
echo ""

# Test 8: Get topic statistics
echo "8️⃣ Get Topic Statistics"
echo "---"
curl -s -X GET "${API_URL}/stats/topics" | python3 -m json.tool
echo ""
