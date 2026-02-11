# AI Analysis Service

Service d'analyse IA utilisant **Google Gemini API** pour une analyse de sentiment professionnelle et l'extraction de topics avancée.

## Features

✨ **Analyse de Sentiment Avancée**
- Utilise Google Gemini pour une compréhension contextuelle profonde
- Score de sentiment (-1.0 à 1.0) avec confiance
- Résumé explicatif généré par l'IA

🏷️ **Extraction de Topics Intelligente**
- Topics détectés : performance, quality, battery, connectivity, design, price, comfort, customer_support, heat_noise, display, etc.
- Analyse contextuelle avec Gemini
- Topics basés sur le rating (negative_experience, highly_satisfied)

🔄 **Fallback Automatique**
- Si Gemini API échoue, utilise une analyse par mot-clé
- Assure la continuité du service

## Installation

### 1. Obtenir une clé API Gemini

1. Allez sur [Google AI Studio](https://aistudio.google.com/app/apikeys)
2. Cliquez sur "Create API Key"
3. Copiez la clé API

### 2. Configuration

```bash
# Créer le fichier .env
cp .env.example .env

# Ajouter votre clé API Gemini
echo "GEMINI_API_KEY=votre_clé_api_ici" >> .env
```

### 3. Installer les dépendances

```bash
pip install -r requirements.txt
```

### 4. Lancer le service

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Endpoints API

### Health Check
```
GET /health
```

### Analyser une revue
```
POST /analyze
Content-Type: application/json

{
    "review_text": "Ce produit est excellent! Très rapide et durable.",
    "rating": 5
}

Response:
{
    "sentiment": "positive",
    "sentiment_score": 0.95,
    "topics": ["quality", "performance", "highly_satisfied"],
    "details": {
        "positive": 1.0,
        "negative": 0.0,
        "neutral": 0.0
    }
}
```

### Analyser toutes les revues
```
GET /analyze/reviews/all
```

### Statistiques de Sentiment
```
GET /stats/sentiment
```

### Statistiques de Topics
```
GET /stats/topics
```

## Variables d'Environnement

| Variable | Description | Requis |
|----------|-------------|--------|
| `GEMINI_API_KEY` | Clé API Google Gemini | ✅ Oui |
| `DB_HOST` | Host de la base de données | Non (default: localhost) |
| `DB_PORT` | Port PostgreSQL | Non (default: 5432) |
| `DB_NAME` | Nom de la base de données | Non (default: product_insights) |
| `DB_USER` | Utilisateur DB | Non (default: app_user) |
| `DB_PASSWORD` | Mot de passe DB | Non (default: app_password) |

## Architecture

```
┌─────────────────────────────────────┐
│   FastAPI Application               │
├─────────────────────────────────────┤
│  /health        - Health check      │
│  /analyze       - Single review     │
│  /analyze/reviews/all - Batch       │
│  /stats/sentiment     - Stats       │
│  /stats/topics        - Stats       │
└──────────────┬──────────────────────┘
               │
       ┌───────┴──────────┐
       │                  │
   ┌────────────┐   ┌──────────┐
   │   Gemini   │   │PostgreSQL│
   │    API     │   │   DB     │
   └────────────┘   └──────────┘
```

## Modèle Gemini

Actuellement utilise **gemini-2.0-flash** pour:
- Rapidité de réponse optimale
- Coût réduit
- Performance excellente pour l'analyse de texte

Vous pouvez changer le modèle en modifiant la variable `MODEL_NAME` dans `main.py`.

## Modèles Disponibles

- `gemini-2.0-flash` (✅ Recommandé) - Rapide et économique
- `gemini-1.5-pro` - Plus puissant, coût plus élevé
- `gemini-1.5-flash` - Équilibre rapide/puissant

## Tarification Gemini

Consultez [Google AI Pricing](https://ai.google.dev/pricing)

- 1M tokens input: ~$0.075
- 1M tokens output: ~$0.30

## Troubleshooting

### "GEMINI_API_KEY environment variable not set"
```bash
# Vérifier que la variable est définie
echo $GEMINI_API_KEY

# Ou charger depuis un fichier .env
source .env
```

### Erreur de connexion à l'API
- Vérifiez votre clé API sur [Google AI Studio](https://aistudio.google.com/app/apikeys)
- Vérifiez votre connexion internet
- Le fallback automatique analysera les mots-clés

### Erreur de base de données
- Vérifiez les variables DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- Assurez-vous que PostgreSQL est en cours d'exécution

## Performance

- Temps moyen par analyse: 1-2 secondes (dépend de Gemini)
- Batch (100 revues): ~100-200 secondes
- Fallback (hors ligne): <100ms
