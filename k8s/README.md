# Kubernetes Deployment - AI Product Insights Platform

Architecture Kubernetes production-ready pour l'AI Product Insights Platform avec microservices backend, PostgreSQL et frontend React.

## 📋 Vue d'ensemble de l'architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Ingress Controller (Nginx)              │
│                    (Port 80/443 externe)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌─────────┐    ┌──────────────┐   ┌────────────┐
   │Frontend │    │ Stats API    │   │ Scraper    │
   │Dashboard│    │ (Stats SVC)  │   │ (FastAPI)  │
   │(React)  │    │ :8000        │   │ :8000      │
   └─────────┘    └──────────────┘   └────────────┘
        │                │                │
        │ ┌──────────────┼────────────────┘
        │ │              │
        │ │              ▼
        │ │         ┌──────────────┐
        │ │         │ AI Analysis  │
        │ │         │ Service      │
        │ │         │ (VADER NLP)  │
        │ │         │ :8000        │
        │ │         └──────────────┘
        │ │              │
        └─┴──────────────┼──────────┐
                         │          │
                         ▼          │
                    ┌────────────┐  │
                    │ PostgreSQL │◄─┘
                    │ Database   │
                    │ :5432      │
                    │ (PVC 10Gi) │
                    └────────────┘
```

## 📂 Structure des fichiers

```
k8s/
├── 00-namespace.yaml           # Namespace ai-product-insights
├── 01-secrets.yaml             # PostgreSQL credentials + ConfigMap
├── 02-postgres-pvc.yaml        # PersistentVolumeClaim + Init script
├── 03-postgres-deployment.yaml # PostgreSQL deployment + service
├── 04-scraper-service.yaml     # Scraper Service deployment + service
├── 05-ai-analysis-service.yaml # AI Analysis Service deployment + service
├── 06-stats-service.yaml       # Stats Service deployment + service
├── 07-frontend-deployment.yaml # React Dashboard deployment + service
├── 08-ingress.yaml             # Ingress configuration (local + domains)
├── 09-hpa.yaml                 # HorizontalPodAutoscaler pour tous les services
├── 10-network-policies.yaml    # NetworkPolicies pour la sécurité
└── README.md                   # Documentation (ce fichier)
```

## 🚀 Quick Start

### Prérequis
- Kubernetes cluster (v1.20+) - Kind, Minikube, EKS, GKE, etc.
- `kubectl` CLI configuré
- Nginx Ingress Controller (optionnel pour localhost)
- Images Docker pushées sur Docker Hub:
  - `saifdine23/scraper-service:latest`
  - `saifdine23/ai-analysis-service:latest`
  - `saifdine23/stats-service:latest`
  - `saifdine23/dashboard-frontend:latest`

### Installation avec Kind (local)

```bash
# 1. Créer un cluster Kind avec support Ingress
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ai-product-insights
nodes:
- role: control-plane
  ports:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

# 2. Installer Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml

# 3. Attendre que l'Ingress soit prêt
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Déployer l'application

```bash
# 1. Appliquer tous les manifests en une seule commande
kubectl apply -f k8s/

# 2. Vérifier que tous les ressources sont créées
kubectl get all -n ai-product-insights

# 3. Attendre que tous les pods soient en Running
kubectl get pods -n ai-product-insights --watch

# 4. Vérifier les endpoints (services)
kubectl get endpoints -n ai-product-insights
```

### Accéder à l'application

```bash
# Frontend Dashboard
open http://localhost

# Stats API
curl http://localhost/api/stats/sentiment

# Vérifier les logs
kubectl logs -n ai-product-insights -l app=stats-service -f
```

## 📊 Détails des déploiements

### PostgreSQL (03-postgres-deployment.yaml)
- **Image**: `postgres:16-alpine`
- **Replicas**: 1 (StatefulSet recommandé pour production)
- **Storage**: PVC 10Gi (modifiable)
- **Health Checks**: 
  - Liveness: `pg_isready` toutes les 10s
  - Readiness: `pg_isready` toutes les 5s
- **Resources**: 256Mi RAM, 250m CPU (limits: 512Mi/500m)
- **Credentials**: Secret `postgres-credentials`
- **Init Script**: ConfigMap `postgres-init-script`

### Backend Services (04-06)
Chaque service (Scraper, AI Analysis, Stats) a:
- **Replicas**: 1 (escalable via HPA)
- **Image**: saifdine23/* depuis Docker Hub
- **Port**: 8000 (FastAPI default)
- **Health Checks**: 
  - Liveness: `GET /health` (30s timeout)
  - Readiness: `GET /health` (10s timeout)
- **Resources**: 128-256Mi RAM, 100-200m CPU
- **Security**: Non-root user, readOnlyRootFilesystem
- **Networking**: ClusterIP service, accessible intra-cluster

### Frontend Dashboard (07-frontend-deployment.yaml)
- **Replicas**: 2 (pour haute disponibilité)
- **Image**: saifdine23/dashboard-frontend
- **Port**: 80 (Nginx)
- **Health Checks**: HTTP GET `/`
- **Resources**: 64Mi RAM, 50m CPU
- **Security**: Non-root (nginx user), readOnlyRootFilesystem
- **Pod Anti-Affinity**: Distribution sur différents nœuds

### Ingress (08-ingress.yaml)
- **Controller**: nginx
- **Routes**:
  - `/` → dashboard-frontend:80 (frontend)
  - `/api/stats` → stats-service:8000 (API)
  - `/api/scraper` → scraper-service:8000 (debug)
  - `/api/ai-analysis` → ai-analysis-service:8000 (debug)
- **CORS**: Activé pour toutes les origines
- **Features**: Compression, timeout configurés

### HPA - Auto-Scaling (09-hpa.yaml)
Chaque service a un HorizontalPodAutoscaler:
- **Min Replicas**: 1 (Frontend: 2)
- **Max Replicas**: 3 (Frontend: 5)
- **Triggers**: CPU > 70-75%, Memory > 80-85%
- **Scale-up**: Immédiat (0s stabilization)
- **Scale-down**: 5 min stabilization

### Network Policies (10-network-policies.yaml)
Sécurité par défaut (deny-all) avec règles spécifiques:
- PostgreSQL: Accepte uniquement des services backend
- Services backend: Sortie vers PostgreSQL + DNS
- Frontend: Entrée depuis Ingress, sortie vers APIs
- Communication intra-cluster: Explicitement autorisée

## 🔧 Configuration et secrets

### Secrets (01-secrets.yaml)
```yaml
username: YXBwX3VzZXI=  # app_user (base64)
password: YXBwX3Bhc3N3b3Jk  # app_password (base64)
database: cHJvZHVjdF9pbnNpZ2h0cw==  # product_insights (base64)
```

**Pour changer les credentials:**
```bash
# Générer nouveau secret
kubectl create secret generic postgres-credentials \
  --from-literal=username=newuser \
  --from-literal=password=newpass \
  --from-literal=database=dbname \
  -n ai-product-insights \
  -o yaml > new-secret.yaml

# Appliquer
kubectl apply -f new-secret.yaml
kubectl rollout restart deployment/postgres -n ai-product-insights
```

### ConfigMap (01-secrets.yaml)
Variables non-sensibles:
- `POSTGRES_HOST: postgres-service`
- `POSTGRES_PORT: 5432`
- `DB_NAME: product_insights`
- Services URLs
- Log level

## 📈 Monitoring et débogage

### Vérifier les pods
```bash
# Status global
kubectl get pods -n ai-product-insights

# Logs d'un service
kubectl logs -n ai-product-insights deployment/stats-service -f

# Description détaillée
kubectl describe pod <pod-name> -n ai-product-insights

# Accès au pod (terminal)
kubectl exec -it <pod-name> -n ai-product-insights -- sh
```

### Vérifier les services
```bash
# Lister tous les services
kubectl get services -n ai-product-insights

# Tester connectivité interne
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# À l'intérieur du pod:
# nc -zv stats-service 8000
# nc -zv postgres-service 5432
```

### Vérifier l'Ingress
```bash
# Status Ingress
kubectl get ingress -n ai-product-insights

# Vérifier les règles
kubectl describe ingress ai-product-insights-ingress -n ai-product-insights

# Tester depuis l'hôte
curl -v http://localhost/
curl -v http://localhost/api/stats/sentiment
```

### Vérifier HPA
```bash
# Status HPA
kubectl get hpa -n ai-product-insights

# Métriques détaillées
kubectl describe hpa stats-service-hpa -n ai-product-insights

# Voir l'historique des scale events
kubectl get events -n ai-product-insights --sort-by='.lastTimestamp' | grep HorizontalPodAutoscaler
```

## 🔒 Sécurité

### Network Policies
Les NetworkPolicies activent par défaut une approche "deny-all" pour isoler les services:
- PostgreSQL n'accepte que des requêtes des services backend
- Les services backend ne peuvent sortir que vers PostgreSQL et DNS
- Le frontend ne peut communiquer qu'avec les APIs et l'Ingress
- DNS est autorisé pour la résolution de noms

**Prérequis**: CNI compatible (Calico, Cilium, etc.)

### Pod Security
- Tous les pods tournent en `runAsNonRoot`
- `readOnlyRootFilesystem` pour les services stateless
- `allowPrivilegeEscalation: false`
- `securityContext.capabilities.drop: ALL`

### Secrets
- Les credentials PostgreSQL sont en Secret K8s (base64 encoded)
- Non commitées dans le repo (à générer localement)
- Rotation possible sans redéploiement du code

## 📦 Production Readiness Checklist

- ✅ Déploiements multi-replicas
- ✅ Health checks (liveness + readiness)
- ✅ Resource requests/limits
- ✅ Network policies pour la sécurité
- ✅ Persistent storage (PVC) pour PostgreSQL
- ✅ Secrets K8s pour les credentials
- ✅ HPA pour auto-scaling
- ✅ Ingress pour le routage externe
- ⚠️ Monitoring/Logging (à ajouter: Prometheus + Grafana)
- ⚠️ Backup PostgreSQL (à configurer)
- ⚠️ CI/CD deployment (à intégrer: ArgoCD ou Flux)
- ⚠️ SSL/TLS Certificates (à configurer avec cert-manager)

## 🛠️ Commandes utiles

```bash
# Déployer
kubectl apply -f k8s/

# Mettre à jour une image
kubectl set image deployment/stats-service \
  stats-service=saifdine23/stats-service:v2 \
  -n ai-product-insights

# Redémarrer un service
kubectl rollout restart deployment/stats-service -n ai-product-insights

# Voir l'historique de déploiement
kubectl rollout history deployment/stats-service -n ai-product-insights

# Rollback à une version précédente
kubectl rollout undo deployment/stats-service -n ai-product-insights

# Scale manuel
kubectl scale deployment stats-service --replicas=2 -n ai-product-insights

# Port forward local
kubectl port-forward service/postgres-service 5433:5432 -n ai-product-insights

# Supprimer tout le namespace
kubectl delete namespace ai-product-insights
```

## 📚 Ressources additionnelles

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Kind - Local Kubernetes](https://kind.sigs.k8s.io/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Network Policies Guide](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

## 📝 Notes

1. **Images Docker**: Assurez-vous que les images sont buildées et pushées sur Docker Hub
   ```bash
   docker build -t saifdine23/scraper-service:latest ./backend/scraper-service
   docker build -t saifdine23/ai-analysis-service:latest ./backend/ai-analysis-service
   docker build -t saifdine23/stats-service:latest ./backend/stats-service
   docker build -t saifdine23/dashboard-frontend:latest ./frontend/dashboard-react
   docker push saifdine23/*
   ```

2. **Local development**: Pour Kind, les images doivent être loadées:
   ```bash
   kind load docker-image saifdine23/stats-service:latest --name=ai-product-insights
   ```

3. **Nginx Ingress**: Installez avant d'appliquer les manifests Ingress

4. **Metrics Server**: Requis pour HPA (installé par défaut sur Kind >= 0.11)

5. **Persistent Data**: Les données PostgreSQL persistent même après `kubectl delete pod`

---

**Créé avec ❤️ pour l'AI Product Insights Platform**
**Production-ready • Kubernetes 1.20+ • Open Source**
