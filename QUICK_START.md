# AI Product Insights Platform - Quick Start Guide

> **La plateforme est complète et prête à l'emploi.** Suivez ce guide pour démarrer.

---

## 🚀 Démarrage 60 Secondes (Docker Compose)

### Prérequis
```bash
# Installer Docker & Docker Compose
docker --version  # 24+
docker compose --version  # 2+
```

### Lancer tout
```bash
# Cloner le projet
git clone https://github.com/SAIFDINE23/ai-product-insights-platform.git
cd ai-product-insights-platform

# Démarrer tous les services
docker compose up -d

# Attendre 10 secondes que tout démarre
sleep 10

# Vérifier que tout fonctionne
docker compose ps
```

### Accéder au Dashboard
```
🌐 Frontend: http://localhost:5173
📊 Stats API: http://localhost:8003/stats/sentiment
```

### Analyser les reviews
```bash
# Les 100 reviews sont déjà seeded
# Analyser tout
curl -X POST http://localhost:8002/analyze/reviews/all
```

### Voir les stats
```bash
# Sentiments
curl http://localhost:8003/stats/sentiment | jq .

# Top topics
curl http://localhost:8003/stats/topics?limit=10 | jq .
```

---

## 📱 Dashboard React

### Localisation: `frontend/dashboard-react/`

**Fichiers principaux:**
- `src/App.jsx` - Composant principal (650 lignes commentées)
- `src/index.css` - Styles TailwindCSS
- `package.json` - Dépendances
- `README.md` - Documentation complète

**Fonctionnalités:**
- ✅ Bar chart sentiment distribution (Chart.js)
- ✅ Top 10 topics table avec percentages
- ✅ Total reviews counter
- ✅ Auto-refresh 30 secondes
- ✅ Design responsive TailwindCSS
- ✅ Bouton manual refresh

**Code React prêt à copier-coller:**
```javascript
// Exemple: Lire les sentiments
const response = await fetch('http://localhost:8003/stats/sentiment');
const data = await response.json();
console.log(data);
// Output: {positive: 60, neutral: 24, negative: 16, total: 100}
```

---

## 🔧 Stats Service

### Localisation: `backend/stats-service/`

**Fichiers principaux:**
- `main.py` - API avec endpoints commentés
- `requirements.txt` - Dépendances

**Endpoints:**
```
GET /health
  → {"status": "ok", "service": "stats-service"}

GET /stats/sentiment
  → {"positive": 60, "neutral": 24, "negative": 16, "total": 100}

GET /stats/topics?limit=10
  → [{"topic": "highly_satisfied", "count": 40}, ...]

GET /stats/summary
  → {total_reviews: 100, sentiment: {...}, top_topics: [...]}
```

**Code Python prêt:**
```python
# main.py contient:
# 1. get_sentiment_stats() - SQL GROUP BY sentiment
# 2. get_topic_stats() - SQL UNNEST topics avec COUNT
# 3. get_summary() - Combiner stats + topics
```

---

## 🧠 AI Analysis Service

### Localisation: `backend/ai-analysis-service/`

**Qu'il fait:**
- VADER sentiment analysis (NLTK)
- Topic extraction basée keywords
- Stockage résultats dans PostgreSQL

**Endpoints:**
```
POST /analyze/reviews/all
  → Analyse toutes les 100 reviews + stocke

POST /analyze
  → {"review_text": "Great product!"} 
  → {"sentiment": "positive", "topics": ["quality"]}

GET /analyze/reviews/all
  → Liste toutes les analyses
```

---

## 🗄️ PostgreSQL Database

### Accès local
```bash
# Via Docker
docker exec -it api-postgres psql -U app_user -d product_insights

# Requêtes utiles
SELECT COUNT(*) FROM reviews;  -- 100 reviews
SELECT COUNT(*) FROM reviews_analysis;  -- Analyses
SELECT sentiment, COUNT(*) FROM reviews_analysis GROUP BY sentiment;
SELECT DISTINCT topics FROM reviews_analysis LIMIT 5;
```

### Tables
```sql
-- reviews: Avis clients bruts
CREATE TABLE reviews (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(255),
  rating INTEGER (1-5),
  review_text TEXT,
  channel VARCHAR(50),
  created_at TIMESTAMP
);

-- reviews_analysis: Résultats sentiment + topics
CREATE TABLE reviews_analysis (
  id SERIAL PRIMARY KEY,
  review_id INTEGER REFERENCES reviews(id),
  sentiment VARCHAR(20),  -- 'positive', 'neutral', 'negative'
  confidence FLOAT,       -- Score VADER
  topics TEXT,           -- Comma-separated topics
  analyzed_at TIMESTAMP
);
```

---

## 🔗 Architecture Réseau

### Requests Frontend → Backend
```javascript
// Dans App.jsx
const API_BASE_URL = 'http://localhost:8003';

// Pour Kubernetes, changer en:
const API_BASE_URL = 'http://stats-service:8003';
```

### Services Networking
```
Docker Compose (Bridge Network):
- dashboard-react → stats-service:8003 (localhost dans frontend)
- stats-service → postgres:5432

Kubernetes (Internal DNS):
- dashboard-react → stats-service:8003 (ClusterIP)
- stats-service → postgres-service:5432
```

---

## 📦 Déployer en Production

### Option 1: Docker Hub (Préconfiguré)
```bash
# Les images sont déjà pushées
# Dans infra/kubernetes/ ou docker-compose.yml:
image: saifdine23/stats:latest
```

### Option 2: Build local
```bash
# Build frontend
cd frontend/dashboard-react
npm run build
docker build -f Dockerfile.production -t myregistry/frontend:v1 .
docker push myregistry/frontend:v1

# Build backend services
cd backend/stats-service
docker build -t myregistry/stats:v1 .
docker push myregistry/stats:v1
```

### Option 3: GitHub Actions (Automatique)
```
À chaque push sur main:
1. Code checkout
2. Docker build (4 images)
3. Trivy security scan
4. Push sur Docker Hub
5. Ready pour Kubernetes
```

---

## ☸️ Déployer sur Kubernetes

### Prérequis
```bash
kubectl version --client
kind version  # Si utilisant Kind cluster
```

### Quick Deploy
```bash
# Créer cluster Kind (local)
kind create cluster --name ai-product-insights

# Installer Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Appliquer manifests
kubectl apply -f infra/kubernetes/

# Vérifier
kubectl get pods -n ai-product-insights
kubectl get svc -n ai-product-insights

# Accéder
kubectl port-forward svc/dashboard-react 5173:5173 -n ai-product-insights
# http://localhost:5173
```

### Manifests disponibles
```
infra/kubernetes/
├── namespace.yaml           # Créer namespace
├── postgres-secret.yaml     # DB credentials
├── postgres-pv-pvc.yaml    # Storage
├── postgres-deployment.yaml # Database
├── configmaps.yaml         # Configuration
├── scraper-deployment.yaml
├── ai-analysis-deployment.yaml
├── stats-deployment.yaml
├── dashboard-deployment.yaml
└── ingress.yaml            # Routing
```

---

## 🧪 Tests Rapides

### Health Checks
```bash
#!/bin/bash
# Vérifier tous les services
for port in 8001 8002 8003 5173; do
  echo "Testing localhost:$port..."
  curl -s http://localhost:$port/health 2>/dev/null || echo "FAILED"
done
```

### API Tests
```bash
# Stats Service
curl -s http://localhost:8003/stats/sentiment | jq .

# Topics
curl -s 'http://localhost:8003/stats/topics?limit=5' | jq '.[] | .topic'

# All reviews analysis
curl -s http://localhost:8002/analyze/reviews/all | jq '.[] | {sentiment, topics}' | head -20
```

### Dashboard Test
```bash
# Ouvrir dans le navigateur et tester:
1. Vérifier que le chart affiche les sentiments
2. Vérifier que la table affiche les topics
3. Cliquer "Refresh" et voir les données se mettre à jour
4. Vérifier le timestamp "Last update"
```

---

## 🔍 Déboguer

### Logs en direct
```bash
# Docker Compose
docker compose logs -f stats-service
docker compose logs -f ai-analysis-service
docker compose logs -f dashboard-react

# Kubernetes
kubectl logs -f deployment/stats-service -n ai-product-insights
kubectl logs -f deployment/ai-analysis-service -n ai-product-insights
```

### Issues courants

**Dashboard blanc / pas de data:**
```bash
# Vérifier stats service répond
curl http://localhost:8003/stats/sentiment

# Vérifier CORS activé dans main.py
# Line 35-42 dans backend/stats-service/main.py

# Vérifier reviews_analysis a des données
docker exec api-postgres psql -U app_user -d product_insights -c "SELECT COUNT(*) FROM reviews_analysis;"
```

**Port 5173 déjà utilisé:**
```bash
# Changer port dans docker-compose.yml
ports:
  - "5174:5173"  # External:Internal

# Ou tuer le processus
lsof -i :5173
kill -9 <PID>
```

**PostgreSQL connection refused:**
```bash
# Vérifier que postgres est up
docker compose ps | grep postgres

# Redémarrer
docker compose restart api-postgres
docker compose up -d  # Redémarrer tous
```

---

## 📚 Documentation Complète

| Document | Contenu |
|----------|---------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Architecture complète, data flows, scalability |
| [frontend/dashboard-react/README.md](./frontend/dashboard-react/README.md) | Setup React, Vite, TailwindCSS, deployment |
| [backend/stats-service/main.py](./backend/stats-service/main.py) | Code commenté des endpoints |
| [backend/ai-analysis-service/main.py](./backend/ai-analysis-service/main.py) | Sentiment analysis et topic extraction |
| [.github/workflows/ci-cd.yml](./.github/workflows/ci-cd.yml) | GitHub Actions pipeline |

---

## 🎯 Prochaines Étapes

### Pour développer
1. Modifier `frontend/dashboard-react/src/App.jsx` (contient 650 lignes commentées)
2. Ajouter new endpoints dans `backend/stats-service/main.py`
3. Tester avec `curl` ou Postman
4. Commit & push → CI/CD auto-build

### Pour déployer en prod
1. Configurer authentification Docker Registry
2. Configurer Kubernetes cluster (AWS EKS, GCP GKE, etc.)
3. Changer images dans `infra/kubernetes/` vers votre registry
4. `kubectl apply -f infra/kubernetes/`
5. Ajouter HTTPS avec cert-manager
6. Configurer monitoring (Prometheus + Grafana)

### Pour scale
1. Ajouter HPA (Horizontal Pod Autoscaler)
2. Configurer Redis pour cache
3. Ajouter base de données managée (PostgreSQL RDS)
4. Load testing avec k6 ou locust

---

## 💡 Tips & Tricks

### Reconstruire une image
```bash
docker compose up --build stats-service
```

### Nettoyer tout
```bash
docker compose down -v  # -v remove volumes
docker system prune -a
```

### Exécuter un script dans un container
```bash
docker compose exec ai-analysis-service python scripts/analyze_batch.py
```

### Copier un fichier depuis container
```bash
docker compose cp api-postgres:/var/lib/postgresql/data ./backup/
```

### View Docker stats
```bash
docker stats
```

---

## 🎓 Stack Utilisé

**Frontend:**
- React 18 | Vite 5 | TailwindCSS 3 | Chart.js 4 | Nginx

**Backend:**
- Python 3.11 | FastAPI 0.111 | Uvicorn | NLTK VADER | PostgreSQL 16

**DevOps:**
- Docker | Kubernetes (Kind) | GitHub Actions | Trivy

**Total:** ~1000 lignes de code prêtes à la production

---

## 📞 Support

**GitHub:** https://github.com/SAIFDINE23/ai-product-insights-platform
**Docker Hub:** https://hub.docker.com/u/saifdine23

---

**✨ La plateforme est opérationnelle et prête à l'emploi**

Commandes magiques pour démarrer:
```bash
git clone https://github.com/SAIFDINE23/ai-product-insights-platform.git && cd ai-product-insights-platform && docker compose up -d && sleep 10 && echo "✅ Dashboard: http://localhost:5173"
```
