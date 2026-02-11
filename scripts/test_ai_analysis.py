"""
Python test client for AI Analysis Service
"""

import requests
import json

# API base URL
BASE_URL = "http://localhost:8002"

def test_health():
    """Test health endpoint."""
    print("1️⃣ Testing /health")
    print("-" * 50)
    response = requests.get(f"{BASE_URL}/health")
    print(json.dumps(response.json(), indent=2))
    print()


def test_analyze_positive():
    """Test analyzing positive review."""
    print("2️⃣ Testing POST /analyze - Positive Review")
    print("-" * 50)
    payload = {
        "review_text": "Excellent laptop! Fast processor and great display quality. Highly recommend!",
        "rating": 5
    }
    response = requests.post(f"{BASE_URL}/analyze", json=payload)
    print(json.dumps(response.json(), indent=2))
    print()


def test_analyze_negative():
    """Test analyzing negative review."""
    print("3️⃣ Testing POST /analyze - Negative Review")
    print("-" * 50)
    payload = {
        "review_text": "Broke after 2 weeks of normal use. Very disappointed and frustrated.",
        "rating": 1
    }
    response = requests.post(f"{BASE_URL}/analyze", json=payload)
    print(json.dumps(response.json(), indent=2))
    print()


def test_analyze_neutral():
    """Test analyzing neutral review."""
    print("4️⃣ Testing POST /analyze - Neutral Review")
    print("-" * 50)
    payload = {
        "review_text": "The product works as expected. Nothing special but does the job.",
        "rating": 3
    }
    response = requests.post(f"{BASE_URL}/analyze", json=payload)
    print(json.dumps(response.json(), indent=2))
    print()


def test_analyze_specific_topics():
    """Test analyzing review with specific issues."""
    print("5️⃣ Testing POST /analyze - Specific Topics Detection")
    print("-" * 50)
    payload = {
        "review_text": "Battery life is disappointing. The device gets hot during normal use and disconnects frequently.",
        "rating": 2
    }
    response = requests.post(f"{BASE_URL}/analyze", json=payload)
    print(json.dumps(response.json(), indent=2))
    print()


def test_analyze_all():
    """Test analyzing all reviews in database."""
    print("6️⃣ Testing GET /analyze/reviews/all")
    print("-" * 50)
    response = requests.get(f"{BASE_URL}/analyze/reviews/all")
    print(json.dumps(response.json(), indent=2))
    print()


def test_sentiment_stats():
    """Test getting sentiment statistics."""
    print("7️⃣ Testing GET /stats/sentiment")
    print("-" * 50)
    response = requests.get(f"{BASE_URL}/stats/sentiment")
    print(json.dumps(response.json(), indent=2))
    print()


def test_topic_stats():
    """Test getting topic statistics."""
    print("8️⃣ Testing GET /stats/topics")
    print("-" * 50)
    response = requests.get(f"{BASE_URL}/stats/topics")
    print(json.dumps(response.json(), indent=2))
    print()


def main():
    """Run all tests."""
    print("=" * 50)
    print("AI Analysis Service - Test Suite")
    print("=" * 50)
    print()
    
    try:
        test_health()
        test_analyze_positive()
        test_analyze_negative()
        test_analyze_neutral()
        test_analyze_specific_topics()
        test_analyze_all()
        test_sentiment_stats()
        test_topic_stats()
        
        print("=" * 50)
        print("✅ All tests completed!")
        print("=" * 50)
    except requests.exceptions.ConnectionError:
        print("❌ Error: Could not connect to API")
        print(f"Make sure the service is running at {BASE_URL}")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    main()
