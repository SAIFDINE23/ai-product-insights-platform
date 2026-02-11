# DEPLOYMENT-GUIDE.md - Guide complet de déploiement Kubernetes

## 📚 Table des matières

1. [Architecture Overview](#architecture-overview)
2. [Pre-requisites](#pre-requisites)
3. [Installation Steps](#installation-steps)
4. [Verification](#verification)
5. [Scaling & Monitoring](#scaling--monitoring)
6. [Troubleshooting](#troubleshooting)
7. [Production Deployment](#production-deployment)

---

## Architecture Overview

### Composants

```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (ai-product-insights namespace)      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Frontend (React Dashboard)                             │
│  ├─ 2 replicas (scalable via HPA)                       │
│  ├─ Nginx serving static files                          │
│  └─ Health checks: HTTP GET /                           │
│                                                          │
│  Backend Services (FastAPI microservices)               │
│  ├─ Scraper Service (data collection)                   │
│  ├─ AI Analysis Service (VADER sentiment analysis)      │
│  ├─ Stats Service (aggregation & reporting)             │
│  └─ Each: 1 replica (scalable via HPA to 3)             │
│                                                          │
│  PostgreSQL Database                                    │
│  ├─ Single instance (StatefulSet recommandé)            │
│  ├─ Persistent storage (PVC 10Gi)                       │
│  ├─ Health checks: pg_isready                           │
│  └─ Credentials: Secret (base64 encoded)                │
│                                                          │
│  Networking                                             │
│  ├─ Services: ClusterIP (interne)                       │
│  ├─ Ingress: Route externe vers frontend                │
│  └─ NetworkPolicies: Sécurité par défaut (deny-all)     │
│                                                          │
│  Scaling                                                │
│  └─ HPA pour chaque service basée sur CPU/Memory        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Network Architecture

```
External Request
       │
       ▼
   Ingress (Nginx)
       │
       ├──► dashboard-frontend:80 (2 pods)
       │
       └──► stats-service:8000 (1-3 pods)
            │
            ├──► scraper-service:8000 (1-3 pods)
            │    │
            │    └──► postgresql:5432
            │
            ├──► ai-analysis-service:8000 (1-3 pods)
            │    │
            │    └──► postgresql:5432
            │
            └──► postgresql:5432 (1 pod)
```

---

## Pre-requisites

### Logiciels requis

```bash
# Kubernetes
kubectl version --client

# Pour local development avec Kind
kind version

# Docker (pour builder les images)
docker --version

# Optional: git
git --version
```

### Prérequis cluster

| Composant | Minimum | Recommandé |
|-----------|---------|-----------|
| Kubernetes | 1.20 | 1.27+ |
| CPU | 2 cores | 4+ cores |
| RAM | 4Gi | 8Gi+ |
| Storage | 10Gi | 50Gi+ |
| CNI | - | Calico/Cilium (pour NetworkPolicies) |

### Images Docker

Assurer que les images sont disponibles:

```bash
# Build locally
docker build -t saifdine23/scraper-service:latest ./backend/scraper-service
docker build -t saifdine23/ai-analysis-service:latest ./backend/ai-analysis-service
docker build -t saifdine23/stats-service:latest ./backend/stats-service
docker build -t saifdine23/dashboard-frontend:latest ./frontend/dashboard-react

# Push to registry
docker push saifdine23/scraper-service:latest
docker push saifdine23/ai-analysis-service:latest
docker push saifdine23/stats-service:latest
docker push saifdine23/dashboard-frontend:latest
```

---

## Installation Steps

### Step 1: Créer un cluster Kubernetes

#### Option A: Kind (local development)

```bash
# Configuration avec Ingress support
cat <<EOF | kind create cluster --name=ai-product-insights --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ai-product-insights
nodes:
- role: control-plane
  ports:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
EOF

# Vérifier le cluster
kubectl cluster-info
kubectl get nodes
```

#### Option B: Minikube

```bash
minikube start --cpus=4 --memory=8192 --driver=kvm2 --name=ai-product-insights
minikube addons enable ingress
```

#### Option C: Cloud (EKS, GKE, AKS, DigitalOcean)

```bash
# Exemple EKS (AWS)
aws eks create-cluster --name ai-product-insights --region us-east-1

# Exemple GKE (Google Cloud)
gcloud container clusters create ai-product-insights --zone us-central1-a

# Se connecter au cluster
kubectl config current-context
```

### Step 2: Installer Ingress Controller

#### Pour Kind (Nginx)

```bash
# Installer Nginx Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml

# Attendre que l'Ingress soit prêt
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

#### Pour Minikube

```bash
minikube addons enable ingress
```

#### Pour Cloud (EKS/GKE/AKS)

```bash
# AWS
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Step 3: Configurer les Secrets

```bash
# Les secrets sont définis dans 01-secrets.yaml
# Pour changer les credentials:

kubectl create secret generic postgres-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypass123 \
  --from-literal=database=product_insights \
  -n ai-product-insights \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 4: Appliquer les manifests

```bash
# Method 1: Appliquer tous les manifests d'un coup
kubectl apply -f k8s/

# Method 2: Appliquer dans l'ordre (plus contrôlé)
for f in k8s/00-namespace.yaml \
         k8s/01-secrets.yaml \
         k8s/02-postgres-pvc.yaml \
         k8s/03-postgres-deployment.yaml \
         k8s/04-scraper-service.yaml \
         k8s/05-ai-analysis-service.yaml \
         k8s/06-stats-service.yaml \
         k8s/07-frontend-deployment.yaml \
         k8s/08-ingress.yaml \
         k8s/09-hpa.yaml \
         k8s/10-network-policies.yaml; do
  echo "Applying $f..."
  kubectl apply -f "$f"
  sleep 2
done

# Method 3: Utiliser le script automatisé
./k8s/deploy.sh deploy
```

### Step 5: Attendre que tout soit prêt

```bash
# Vérifier le déploiement en temps réel
kubectl get pods -n ai-product-insights --watch

# Attendre que tous les pods soient Running
kubectl wait --for=condition=Ready \
  pod --all -n ai-product-insights \
  --timeout=300s
```

---

## Verification

### Vérifier tous les composants

```bash
# Pods
kubectl get pods -n ai-product-insights

# Services
kubectl get svc -n ai-product-insights

# Deployments
kubectl get deployment -n ai-product-insights

# Ingress
kubectl get ingress -n ai-product-insights

# HPA
kubectl get hpa -n ai-product-insights

# NetworkPolicies
kubectl get networkpolicies -n ai-product-insights

# PVC
kubectl get pvc -n ai-product-insights

# Secrets
kubectl get secrets -n ai-product-insights
```

### Tester la connectivité

```bash
# Vérifier que PostgreSQL peut se connecter
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U app_user -d product_insights -c "SELECT version();"

# Vérifier que les services backend peuvent accéder à PostgreSQL
kubectl logs -n ai-product-insights deployment/stats-service

# Tester l'API Stats
kubectl port-forward -n ai-product-insights svc/stats-service 8000:8000 &
curl http://localhost:8000/health

# Tester le frontend
open http://localhost
```

### Vérifier les logs

```bash
# Logs d'un pod spécifique
kubectl logs -n ai-product-insights <pod-name>

# Logs avec streaming (tail -f)
kubectl logs -n ai-product-insights deployment/stats-service -f

# Logs de tous les pods d'un label
kubectl logs -n ai-product-insights -l app=stats-service -f

# Logs précédents (si le pod a crashé)
kubectl logs -n ai-product-insights <pod-name> --previous
```

---

## Scaling & Monitoring

### Auto-scaling (HPA)

```bash
# Voir l'état des HPAs
kubectl get hpa -n ai-product-insights

# Détails d'un HPA
kubectl describe hpa stats-service-hpa -n ai-product-insights

# Voir les événements de scaling
kubectl get events -n ai-product-insights \
  --field-selector involvedObject.kind=HorizontalPodAutoscaler

# Métriques (si metrics-server est installé)
kubectl top pods -n ai-product-insights
kubectl top nodes
```

### Scaling manuel

```bash
# Augmenter les replicas
kubectl scale deployment/stats-service --replicas=3 -n ai-product-insights

# Vérifier
kubectl get deployment/stats-service -n ai-product-insights
```

### Monitoring via Prometheus (optionnel)

```bash
# Installer Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Accéder à Prometheus
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Ouvrir: http://localhost:3000 (user: admin, pass: prom-operator)
```

---

## Troubleshooting

### Pod ne démarre pas (Pending)

```bash
# Voir le problème
kubectl describe pod <pod-name> -n ai-product-insights

# Problèmes courants:
# 1. PVC non mounté:
kubectl get pvc -n ai-product-insights

# 2. Pas assez de ressources:
kubectl describe nodes

# 3. Image non trouvée:
kubectl get events -n ai-product-insights --sort-by='.lastTimestamp' | tail -20
```

### Pod crash (CrashLoopBackOff)

```bash
# Voir l'erreur
kubectl logs <pod-name> --previous -n ai-product-insights

# Entrer dans un pod de débogage
kubectl run -it --rm --image=alpine --restart=Never debug -- sh

# À l'intérieur, tester la connexion DB:
apk add postgresql-client
psql -h postgres-service -U app_user -d product_insights -c "SELECT 1"
```

### Services ne communiquent pas

```bash
# Vérifier les NetworkPolicies
kubectl get networkpolicies -n ai-product-insights

# Tester depuis un pod de débogage
kubectl exec -it <pod-debug> -n ai-product-insights -- \
  nc -zv stats-service 8000

# Vérifier les DNS
kubectl exec -it <pod-name> -n ai-product-insights -- \
  nslookup stats-service
```

### Ingress ne route pas

```bash
# Vérifier la config de l'Ingress
kubectl get ingress -n ai-product-insights -o yaml

# Vérifier les endpoints
kubectl get endpoints -n ai-product-insights

# Vérifier les logs du contrôleur Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

---

## Production Deployment

### Checklist de production

```yaml
Sécurité:
  - [ ] Secrets stockés en Vault/AWS Secrets Manager
  - [ ] RBAC configuré (pas de *:*)
  - [ ] NetworkPolicies activées
  - [ ] Pod Security Policies (ou Pod Security Standards)
  - [ ] Container security scanning (Trivy, Clair)
  - [ ] TLS/HTTPS activé

High Availability:
  - [ ] PostgreSQL en HA (Patroni, Replication)
  - [ ] Replicas >= 2 pour chaque service
  - [ ] Pod Disruption Budgets configurés
  - [ ] Node affinity configurée

Monitoring & Logging:
  - [ ] Prometheus pour les métriques
  - [ ] Grafana pour la visualisation
  - [ ] ELK/Loki pour les logs
  - [ ] Alerts configurées (PagerDuty, Slack)

Backup & Disaster Recovery:
  - [ ] PostgreSQL backups automatiques
  - [ ] Restore tests programmés
  - [ ] RTO/RPO documentés

Networking:
  - [ ] Ingress avec TLS
  - [ ] Service mesh (Istio, Linkerd) - optionnel
  - [ ] Network policies strictes
  - [ ] DDoS protection

Performance:
  - [ ] Caching (Redis) - optionnel
  - [ ] Database optimization (indices, vacuum)
  - [ ] Load testing complété
  - [ ] Benchmarks documentés

Operations:
  - [ ] Runbooks documentés
  - [ ] On-call rotation établie
  - [ ] CI/CD pipeline complet
  - [ ] GitOps (ArgoCD/Flux)
```

### Exemple de déploiement Production (GKE)

```bash
# 1. Créer le cluster
gcloud container clusters create ai-product-insights \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --enable-stackdriver-kubernetes \
  --enable-ip-alias \
  --network ai-network \
  --subnetwork ai-subnet

# 2. Se connecter
gcloud container clusters get-credentials ai-product-insights --zone us-central1-a

# 3. Installer cert-manager pour TLS
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 4. Créer Issuer pour Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 5. Mettre à jour Ingress avec TLS
# Modifier k8s/08-ingress.yaml pour ajouter les sections TLS

# 6. Déployer
kubectl apply -f k8s/

# 7. Installer Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

---

## Maintenance courante

### Mises à jour des images

```bash
# 1. Builder et pousser une nouvelle version
docker build -t saifdine23/stats-service:v2 ./backend/stats-service
docker push saifdine23/stats-service:v2

# 2. Mettre à jour le Deployment
kubectl set image deployment/stats-service \
  stats-service=saifdine23/stats-service:v2 \
  -n ai-product-insights

# 3. Attendre la mise à jour
kubectl rollout status deployment/stats-service -n ai-product-insights

# 4. Si problème, rollback
kubectl rollout undo deployment/stats-service -n ai-product-insights
```

### Sauvegarde PostgreSQL

```bash
# Sauvegarde manuelle
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- pg_dump -U app_user product_insights > backup.sql

# Restauration
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U app_user product_insights < backup.sql
```

---

**Dernière mise à jour**: Février 2026  
**Kubernetes**: 1.20+  
**Status**: Production-Ready ✅
