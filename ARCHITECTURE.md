# AI Product Insights Platform - Architecture Complète

## 📐 Vue d'Ensemble de l'Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRONTEND (React + Vite)                      │
│                     Port: 5173 (Dev) / 80 (Prod)                │
│  - Dashboard avec Chart.js pour visualisation                   │
│  - Auto-refresh 30s                                             │
│  - TailwindCSS pour le design                                   │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP/Fetch API
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  MICROSERVICES BACKEND (FastAPI)                │
├─────────────────────┬─────────────────────┬─────────────────────┤
│  Scraper Service    │  AI Analysis Service │   Stats Service    │
│  Port: 8001         │  Port: 8002          │   Port: 8003       │
│  - Collecte reviews │  - VADER Sentiment   │   - Agrégation     │
│  - Web scraping     │  - Topic extraction  │   - Distribution   │
│  - API endpoints    │  - NLP processing    │   - Top topics     │
└─────────────────────┴───────────┬──────────┴─────────────────────┘
                                  │ psycopg2
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DATABASE (PostgreSQL 16)                      │
│                          Port: 5432 (5433 local)                │
│  Tables:                                                        │
│  - reviews (100 rows) - Avis clients bruts                     │
│  - reviews_analysis - Résultats sentiment + topics             │
└─────────────────────────────────────────────────────────────────┘
                                  ▲
                                  │
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION & DÉPLOIEMENT                  │
├─────────────────────┬─────────────────────┬─────────────────────┤
│  Docker Compose     │  Kubernetes (Kind)   │  GitHub Actions    │
│  - Dev local        │  - Prod-like deploy  │  - CI/CD pipeline  │
│  - 5 services       │  - Ingress nginx     │  - Build images    │
│  - Network isolé    │  - PV/PVC storage    │  - Trivy scan      │
│                     │  - Namespaces        │  - Push Docker Hub │
└─────────────────────┴─────────────────────┴─────────────────────┘
```

## 🎯 Stack Technique

### Frontend
- **React 18** - Framework UI moderne
- **Vite 5** - Build tool ultra-rapide
- **TailwindCSS 3** - Utility-first CSS framework
- **Chart.js 4** - Bibliothèque de graphiques
- **react-chartjs-2** - Wrapper React pour Chart.js
- **Nginx** - Serveur web pour production

### Backend
- **Python 3.11** - Langage de programmation
- **FastAPI 0.111** - Framework API haute performance
- **Uvicorn** - Serveur ASGI
- **psycopg2** - Driver PostgreSQL
- **NLTK** - Natural Language Toolkit
- **VADER** - Sentiment analysis lexicon

### Data & Storage
- **PostgreSQL 16** - Base de données relationnelle
- **Docker Volumes** - Persistance des données

### DevOps & Infrastructure
- **Docker 24+** - Conteneurisation
- **Docker Compose** - Orchestration multi-containers
- **Kubernetes (Kind)** - Orchestration production-like
- **GitHub Actions** - CI/CD automation
- **Trivy** - Security vulnerability scanning
- **Docker Hub** - Registry d'images

---

## 📊 Flux de Données

### 1. Collecte des Reviews (Seeding)
```python
# Script: scripts/seed_reviews.py
CSV (100 reviews) → PostgreSQL (table: reviews)
```

**Schéma reviews:**
```sql
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255),
    rating INTEGER,
    review_text TEXT,
    channel VARCHAR(50),
    created_at TIMESTAMP
);
```

### 2. Analyse AI (AI Analysis Service)
```python
# Endpoint: POST /analyze/reviews/all
1. Lire reviews depuis PostgreSQL
2. Pour chaque review:
   - Appliquer VADER sentiment analysis
   - Extraire topics avec keyword matching
3. Insérer dans reviews_analysis
```

**Schéma reviews_analysis:**
```sql
CREATE TABLE reviews_analysis (
    id SERIAL PRIMARY KEY,
    review_id INTEGER REFERENCES reviews(id),
    sentiment VARCHAR(20),  -- 'positive', 'neutral', 'negative'
    confidence FLOAT,       -- Score VADER (0.0 à 1.0)
    topics TEXT,            -- Comma-separated topics
    analyzed_at TIMESTAMP
);
```

### 3. Agrégation Statistiques (Stats Service)
```python
# Endpoint: GET /stats/sentiment
SELECT sentiment, COUNT(*) FROM reviews_analysis GROUP BY sentiment
```

```python
# Endpoint: GET /stats/topics?limit=10
SELECT topic, COUNT(*) 
FROM (SELECT UNNEST(string_to_array(topics, ',')) as topic)
GROUP BY topic ORDER BY COUNT(*) DESC LIMIT 10
```

### 4. Visualisation Frontend
```javascript
// Dashboard React
1. Fetch /stats/sentiment
2. Fetch /stats/topics?limit=10
3. Render Bar Chart (Chart.js)
4. Render Table avec topics
5. Auto-refresh toutes les 30s
```

---

## 🔐 Architecture Réseau

### Docker Compose (Développement Local)
```yaml
networks:
  app-net:
    driver: bridge

Services:
  postgres:       5433:5432  (conflit résolu)
  scraper:        8001:8001
  ai-analysis:    8002:8002
  stats:          8003:8003
  dashboard:      5173:5173
```

**Connectivité:**
- Frontend → Stats Service: `http://localhost:8003`
- Stats Service → PostgreSQL: `postgres:5432` (nom DNS interne)
- AI Analysis → PostgreSQL: `postgres:5432`

### Kubernetes (Production)
```yaml
Namespace: ai-product-insights

Services ClusterIP:
  postgres-service:        5432
  scraper-service:         8001
  ai-analysis-service:     8002
  stats-service:           8003
  dashboard-react:         5173

Ingress (nginx):
  / → dashboard-react:5173
  /api/scraper → scraper-service:8001
  /api/analysis → ai-analysis-service:8002
  /api/stats → stats-service:8003
```

**Connectivité interne:**
- Frontend → Stats: `http://stats-service:8003`
- Stats → PostgreSQL: `http://postgres-service:5432`

---

## 🚀 Déploiement Multi-Environnement

### 1. Développement Local (Docker Compose)

**Prérequis:**
```bash
docker --version  # 24+
docker compose --version  # 2+
```

**Démarrage:**
```bash
cd /home/saif/projects/Product_Insights
docker compose up -d
docker compose ps
```

**Tests:**
```bash
# Health checks
curl http://localhost:8001/health  # Scraper
curl http://localhost:8002/health  # AI Analysis
curl http://localhost:8003/health  # Stats
curl http://localhost:5173         # Frontend

# API tests
curl http://localhost:8003/stats/sentiment
curl http://localhost:8003/stats/topics?limit=5

# Logs
docker compose logs ai-analysis-service -f
```

**Seed database:**
```bash
python scripts/seed_reviews.py
```

**Analyser reviews:**
```bash
curl -X POST http://localhost:8002/analyze/reviews/all
```

**Accès dashboard:**
```
http://localhost:5173
```

---

### 2. Production Kubernetes (Kind)

**Prérequis:**
```bash
kubectl version --client
kind version
```

**Création cluster:**
```bash
kind create cluster --name ai-product-insights --config infra/kind-config.yaml
```

**Installation Ingress Controller:**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

**Déploiement application:**
```bash
# Appliquer tous les manifests
kubectl apply -f infra/kubernetes/

# Vérifier les pods
kubectl get pods -n ai-product-insights

# Vérifier les services
kubectl get svc -n ai-product-insights

# Logs
kubectl logs deployment/stats-service -n ai-product-insights
```

**Chargement images Docker:**
```bash
# Build images
docker compose build

# Charger dans Kind
kind load docker-image product_insights-scraper-service --name ai-product-insights
kind load docker-image product_insights-ai-analysis-service --name ai-product-insights
kind load docker-image product_insights-stats-service --name ai-product-insights
kind load docker-image product_insights-dashboard-react --name ai-product-insights
```

**Port-forward pour tests:**
```bash
kubectl port-forward svc/dashboard-react 5173:5173 -n ai-product-insights
kubectl port-forward svc/stats-service 8003:8003 -n ai-product-insights

# Accès: http://localhost:5173
```

**Ingress:**
```bash
# Si Kind cluster configuré avec extraPortMappings
curl http://localhost/
```

---

### 3. CI/CD GitHub Actions

**Workflow:** `.github/workflows/ci-cd.yml`

**Pipeline Steps:**
```yaml
1. Checkout code
2. Setup Docker Buildx
3. Login to Docker Hub
4. Build images:
   - saifdine23/scraper:latest
   - saifdine23/ai-analysis:latest
   - saifdine23/stats:latest
   - saifdine23/frontend:latest
5. Security scan avec Trivy
6. Push to Docker Hub
```

**Déclenchement:**
- Push sur branche `main`
- Manual trigger

**Secrets requis:**
```
DOCKERHUB_USERNAME=saifdine23
DOCKERHUB_TOKEN=<token>
```

**Utilisation images CI/CD:**
```yaml
# infra/kubernetes/deployments.yaml
spec:
  containers:
  - name: stats
    image: saifdine23/stats:latest
```

---

## 📦 Gestion des Dépendances

### Frontend (package.json)
```json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "chart.js": "^4.4.1",
    "react-chartjs-2": "^5.2.0"
  },
  "devDependencies": {
    "vite": "^5.3.5",
    "tailwindcss": "^3.4.1",
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.35"
  }
}
```

### Backend (requirements.txt)
```txt
# AI Analysis Service
fastapi==0.111.0
uvicorn[standard]==0.30.1
psycopg2-binary==2.9.9
nltk==3.8.1

# Stats Service
fastapi==0.111.0
uvicorn[standard]==0.30.1
psycopg2-binary==2.9.9

# Scraper Service
fastapi==0.111.0
uvicorn[standard]==0.30.1
```

---

## 🔍 Monitoring & Debugging

### Logs Docker Compose
```bash
# Tous les services
docker compose logs -f

# Service spécifique
docker compose logs stats-service -f

# Last 100 lines
docker compose logs --tail=100 ai-analysis-service
```

### Logs Kubernetes
```bash
# Tous les pods dans namespace
kubectl logs -l app=stats-service -n ai-product-insights

# Pod spécifique
kubectl logs stats-service-7d9f8b6c5d-kxm2p -n ai-product-insights

# Follow logs
kubectl logs -f deployment/stats-service -n ai-product-insights

# Previous pod (si crashed)
kubectl logs stats-service-7d9f8b6c5d-kxm2p --previous -n ai-product-insights
```

### Debug Database
```bash
# Docker Compose
docker exec -it api-postgres psql -U app_user -d product_insights

# Queries
SELECT COUNT(*) FROM reviews;
SELECT sentiment, COUNT(*) FROM reviews_analysis GROUP BY sentiment;
SELECT * FROM reviews_analysis LIMIT 10;

# Kubernetes
kubectl exec -it postgres-7c8f9d5b4-abc123 -n ai-product-insights -- psql -U app_user -d product_insights
```

### Health Checks
```bash
# Script de vérification
#!/bin/bash
services=("scraper-service:8001" "ai-analysis-service:8002" "stats-service:8003" "dashboard-react:5173")

for svc in "${services[@]}"; do
  name="${svc%:*}"
  port="${svc#*:}"
  echo -n "Checking $name... "
  if curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
    echo "✅ OK"
  else
    echo "❌ FAILED"
  fi
done
```

---

## 🛡️ Sécurité

### 1. Secrets Management

**Docker Compose (.env):**
```env
DB_PASSWORD=app_password
DOCKERHUB_TOKEN=<token>
```

**Kubernetes Secrets:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ai-product-insights
type: Opaque
stringData:
  POSTGRES_USER: app_user
  POSTGRES_PASSWORD: app_password
  POSTGRES_DB: product_insights
```

### 2. Security Scanning (Trivy)

**Configuration GitHub Actions:**
```yaml
- name: Trivy Scan - Stats
  uses: aquasecurity/trivy-action@0.23.0
  with:
    image-ref: saifdine23/stats:latest
    format: table
    severity: CRITICAL,HIGH
    exit-code: 0  # Report only, don't block
```

**Scan local:**
```bash
trivy image saifdine23/stats:latest
```

### 3. Network Policies (À implémenter)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: stats-service-policy
  namespace: ai-product-insights
spec:
  podSelector:
    matchLabels:
      app: stats-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: dashboard-react
    ports:
    - protocol: TCP
      port: 8003
```

---

## 📈 Scalabilité

### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stats-service-hpa
  namespace: ai-product-insights
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stats-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Database Connection Pooling
```python
# À implémenter avec psycopg2.pool
from psycopg2 import pool

connection_pool = pool.SimpleConnectionPool(
    minconn=1,
    maxconn=10,
    **DB_CONFIG
)
```

---

## 🎓 Bonnes Pratiques Appliquées

### 1. Architecture Microservices
✅ Séparation des responsabilités (Scraper, AI, Stats, Frontend)
✅ Communication via API REST
✅ Déploiement indépendant de chaque service

### 2. Containerization
✅ Multi-stage builds pour optimiser taille images
✅ Images Alpine Linux (légères)
✅ .dockerignore pour exclure fichiers inutiles

### 3. CI/CD
✅ Automated builds sur push
✅ Security scanning avec Trivy
✅ Versioning des images (latest + commit SHA)

### 4. Observabilité
✅ Health check endpoints (/health)
✅ Logs structurés
✅ Metrics endpoints (à implémenter)

### 5. Documentation
✅ README par service
✅ Commentaires dans le code
✅ Architecture diagrams
✅ Exemples d'utilisation

---

## 🔮 Améliorations Futures

### Court Terme
- [ ] Ajouter tests unitaires (pytest, jest)
- [ ] Implémenter readiness/liveness probes K8s
- [ ] Ajouter métriques Prometheus
- [ ] Configurer HPA (Horizontal Pod Autoscaler)

### Moyen Terme
- [ ] Migration vers base de données managée (RDS)
- [ ] Implémenter cache Redis pour stats
- [ ] Ajouter authentification JWT
- [ ] Dashboard Grafana pour monitoring

### Long Terme
- [ ] Migration vers GKE/EKS
- [ ] Implémenter ML models custom (au lieu VADER)
- [ ] API Gateway (Kong/Nginx)
- [ ] Service Mesh (Istio)

---

## 📞 Support & Contact

**Repository GitHub:**
https://github.com/SAIFDINE23/ai-product-insights-platform

**Docker Hub:**
https://hub.docker.com/u/saifdine23

**Documentation:**
- Frontend: [frontend/dashboard-react/README.md](../frontend/dashboard-react/README.md)
- Backend Services: Voir README dans chaque dossier backend/

---

**Created with ❤️ by SAIFDINE23**
*AI Product Insights Platform - Production-ready sentiment analysis platform*
