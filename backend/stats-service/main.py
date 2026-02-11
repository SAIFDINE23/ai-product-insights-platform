"""
Stats Service - AI Product Insights Platform

Ce microservice fournit des statistiques agrégées sur les reviews analysées:
- Distribution des sentiments (positive/neutral/negative)
- Top topics les plus fréquents
- Statistiques globales

Architecture:
- API REST avec FastAPI
- Connexion PostgreSQL pour lire les reviews_analysis
- Endpoints optimisés avec GROUP BY SQL
- CORS activé pour permettre les requêtes du frontend React

Endpoints:
- GET /health - Health check
- GET /stats/sentiment - Distribution des sentiments
- GET /stats/topics - Top topics avec count
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psycopg2
import os
from typing import List, Dict, Any

app = FastAPI(
    title="Stats Service",
    version="1.0.0",
    description="Service de statistiques pour l'analyse de sentiment"
)

# Configuration CORS pour permettre les requêtes du frontend
# En production, remplacer "*" par l'URL exacte du frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En prod: ["http://localhost:5173", "http://dashboard-react:5173"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration de la base de données depuis les variables d'environnement
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "postgres"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "product_insights"),
    "user": os.getenv("DB_USER", "app_user"),
    "password": os.getenv("DB_PASSWORD", "app_password")
}


def get_db_connection():
    """
    Crée une connexion à la base de données PostgreSQL
    Utilise les paramètres définis dans DB_CONFIG
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        raise


@app.get("/health")
def health():
    """
    Health check endpoint
    Utilisé par Kubernetes pour vérifier que le service est en bonne santé
    """
    return {
        "status": "ok",
        "service": "stats-service",
        "version": "1.0.0"
    }


@app.get("/stats/sentiment")
def get_sentiment_stats() -> Dict[str, int]:
    """
    Retourne la distribution des sentiments des reviews analysées
    
    SQL Query:
    SELECT sentiment, COUNT(*) as count
    FROM reviews_analysis
    GROUP BY sentiment
    
    Returns:
        {
            "positive": 45,
            "neutral": 30,
            "negative": 25,
            "total": 100
        }
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Requête SQL pour compter les reviews par sentiment
        query = """
            SELECT sentiment, COUNT(*) as count
            FROM reviews_analysis
            GROUP BY sentiment
        """
        cursor.execute(query)
        results = cursor.fetchall()
        
        # Initialiser les compteurs à 0
        stats = {
            "positive": 0,
            "neutral": 0,
            "negative": 0,
            "total": 0
        }
        
        # Remplir les stats avec les résultats de la DB
        for sentiment, count in results:
            if sentiment in stats:
                stats[sentiment] = count
                stats["total"] += count
        
        return stats
        
    except Exception as e:
        print(f"Error fetching sentiment stats: {e}")
        return {
            "positive": 0,
            "neutral": 0,
            "negative": 0,
            "total": 0,
            "error": str(e)
        }
    finally:
        cursor.close()
        conn.close()


@app.get("/stats/topics")
def get_topic_stats(limit: int = 10) -> List[Dict[str, Any]]:
    """
    Retourne les topics les plus fréquents avec leur nombre d'occurrences
    
    Args:
        limit: Nombre maximum de topics à retourner (défaut: 10)
    
    SQL Query:
    Parses comma-separated topics string into individual topics
    
    Returns:
        [
            {"topic": "battery", "count": 45},
            {"topic": "performance", "count": 38},
            {"topic": "quality", "count": 32}
        ]
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Requête SQL pour compter les topics
        # Split topics string by comma and count each topic
        query = """
            SELECT topic, COUNT(*) as count
            FROM (
                SELECT TRIM(UNNEST(string_to_array(topics, ','))) as topic
                FROM reviews_analysis
                WHERE topics IS NOT NULL AND topics != ''
            ) subquery
            WHERE topic != ''
            GROUP BY topic
            ORDER BY count DESC
            LIMIT %s
        """
        cursor.execute(query, (limit,))
        results = cursor.fetchall()
        
        # Formater les résultats en liste de dictionnaires
        topic_stats = [
            {"topic": topic, "count": count}
            for topic, count in results
        ]
        
        return topic_stats
        
    except Exception as e:
        print(f"Error fetching topic stats: {e}")
        return []
    finally:
        cursor.close()
        conn.close()


@app.get("/stats/summary")
def get_summary() -> Dict[str, Any]:
    """
    Retourne un résumé complet des statistiques
    Combine sentiment + topics + métadonnées
    
    Returns:
        {
            "total_reviews": 100,
            "sentiment": {...},
            "top_topics": [...],
            "timestamp": "2026-02-11T10:30:00"
        }
    """
    from datetime import datetime
    
    sentiment_stats = get_sentiment_stats()
    topic_stats = get_topic_stats(limit=5)
    
    return {
        "total_reviews": sentiment_stats.get("total", 0),
        "sentiment": sentiment_stats,
        "top_topics": topic_stats,
        "timestamp": datetime.now().isoformat()
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
