# Quick Reference - AI Product Insights K8s Deployment
# Commandes essentielles pour déployer et maintenir l'application

## 🚀 QUICK START (30 secondes)

### Option 1: Script automatisé
```bash
cd k8s/
chmod +x deploy.sh
./deploy.sh full-setup      # Tout en une seule commande!
```

### Option 2: Manuel étape par étape
```bash
# 1. Créer cluster Kind
kind create cluster --name ai-product-insights

# 2. Installer Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml

# 3. Appliquer manifests
kubectl apply -f k8s/

# 4. Attendre (30-60 secondes)
kubectl get pods -n ai-product-insights --watch

# 5. Accéder à l'app
open http://localhost
```

---

## 📋 MANIFESTS ORDER (ordre d'application)

```
1. 00-namespace.yaml        ← Crée le namespace
2. 01-secrets.yaml          ← Credentials + ConfigMaps
3. 02-postgres-pvc.yaml     ← Storage PostgreSQL
4. 03-postgres-deployment.yaml ← Database
5. 04-scraper-service.yaml      ← Backend services...
6. 05-ai-analysis-service.yaml
7. 06-stats-service.yaml
8. 07-frontend-deployment.yaml  ← Frontend
9. 08-ingress.yaml              ← Routing externe
10. 09-hpa.yaml                 ← Auto-scaling
11. 10-network-policies.yaml    ← Sécurité réseau
```

**Application en une ligne:**
```bash
kubectl apply -f k8s/
```

---

## 🔍 VÉRIFIER L'ÉTAT

```bash
# Tous les pods
kubectl get pods -n ai-product-insights

# Tous les services
kubectl get svc -n ai-product-insights

# Ingress
kubectl get ingress -n ai-product-insights

# Détails complets
kubectl get all -n ai-product-insights

# Logs d'un pod
kubectl logs -n ai-product-insights deployment/stats-service -f

# Port forwards (accès direct)
kubectl port-forward -n ai-product-insights \
  svc/postgres-service 5433:5432 &
```

---

## 🌐 ACCÉDER À L'APPLICATION

| Service | URL | Commande |
|---------|-----|----------|
| Frontend | http://localhost | `open http://localhost` |
| Stats API | http://localhost/api/stats/sentiment | `curl http://localhost/api/stats/sentiment` |
| Scraper API | http://localhost/api/scraper/health | Debug only |
| PostgreSQL | localhost:5433 | `psql -h localhost -p 5433 -U app_user -d product_insights` |

---

## 🔧 MAINTENANCE QUOTIDIENNE

### Redémarrer un service
```bash
kubectl rollout restart deployment/stats-service -n ai-product-insights
```

### Voir les logs en temps réel
```bash
kubectl logs -f -n ai-product-insights -l app=stats-service
```

### Mettre à jour l'image
```bash
kubectl set image deployment/stats-service \
  stats-service=saifdine23/stats-service:v2 \
  -n ai-product-insights --record
```

### Scaler manuellement
```bash
kubectl scale deployment/stats-service --replicas=3 -n ai-product-insights
```

### Voir l'historique de déploiement
```bash
kubectl rollout history deployment/stats-service -n ai-product-insights
kubectl rollout undo deployment/stats-service -n ai-product-insights --to-revision=1
```

### Entrer dans un pod
```bash
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=stats-service -o jsonpath='{.items[0].metadata.name}') \
  -- bash
```

---

## 📊 MONITORING (HPA & METRICS)

### Auto-scaling status
```bash
# Voir tous les HPAs
kubectl get hpa -n ai-product-insights

# Détails d'un HPA
kubectl describe hpa stats-service-hpa -n ai-product-insights

# Voir les metrics (si metrics-server est installé)
kubectl top nodes
kubectl top pods -n ai-product-insights
```

---

## 🔒 SÉCURITÉ

### Vérifier Network Policies
```bash
kubectl get networkpolicies -n ai-product-insights

# Tester connectivité entre pods
kubectl run -it --rm --image=alpine --restart=Never debug -- sh
# À l'intérieur:
# apk add --no-cache netcat-openbsd
# nc -zv stats-service 8000
# nc -zv postgres-service 5432
```

### Vérifier Security Contexts
```bash
kubectl get pods -n ai-product-insights -o jsonpath='{range .items[*]}{.metadata.name} {.spec.containers[*].securityContext}{"\n"}{end}'
```

---

## 🗑️ CLEANUP

### Supprimer le namespace entier
```bash
kubectl delete namespace ai-product-insights
```

### Supprimer le cluster Kind
```bash
kind delete cluster --name ai-product-insights
```

### Reset complet
```bash
kind delete cluster --name ai-product-insights
rm -rf k8s/  # ⚠️ Attention!
```

---

## 🐛 DÉPANNAGE

### Pod stuck en "Pending"
```bash
# Voir pourquoi
kubectl describe pod <pod-name> -n ai-product-insights

# Souvent: pas assez de ressources ou PVC non bound
kubectl get pvc -n ai-product-insights
```

### Pod crash (CrashLoopBackOff)
```bash
# Voir les logs d'erreur
kubectl logs <pod-name> --previous -n ai-product-insights

# Ou en détail
kubectl describe pod <pod-name> -n ai-product-insights
```

### Connexion DB échoue
```bash
# Vérifier si PostgreSQL est ready
kubectl get pod -n ai-product-insights -l app=postgresql

# Tester la connexion
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U app_user -d product_insights -c "SELECT 1"
```

### Ingress ne route pas vers le frontend
```bash
# Vérifier l'Ingress config
kubectl get ingress ai-product-insights-ingress -n ai-product-insights -o yaml

# Vérifier les endpoints du service
kubectl get endpoints dashboard-frontend -n ai-product-insights

# Test DNS
kubectl run -it --rm --image=alpine --restart=Never test -- \
  nslookup dashboard-frontend.ai-product-insights
```

---

## 📈 PRODUCTION DEPLOYMENT CHECKLIST

- [ ] Images Docker buildées et pushées sur registry privé/public
- [ ] Secrets créés (credentials PostgreSQL)
- [ ] PVC Storage Class disponible sur le cluster
- [ ] Ingress Controller installé (nginx)
- [ ] Network Policies activées (CNI compatible)
- [ ] Metrics Server installé (pour HPA)
- [ ] Resource quotas définis (optionnel mais recommandé)
- [ ] Pod Disruption Budgets configurés
- [ ] Backup stratégie pour PostgreSQL
- [ ] Monitoring/Logging (Prometheus, ELK, Datadog)
- [ ] SSL/TLS avec cert-manager
- [ ] RBAC policies configurées
- [ ] Image pull secrets si registry privé

---

## 🎯 CAS D'USAGE COURANTS

### Déployer une nouvelle version
```bash
# 1. Build + push nouvelle image
docker build -t saifdine23/stats-service:v2 ./backend/stats-service
docker push saifdine23/stats-service:v2

# 2. Mettre à jour le deployment
kubectl set image deployment/stats-service \
  stats-service=saifdine23/stats-service:v2 \
  -n ai-product-insights --record

# 3. Vérifier le rollout
kubectl rollout status deployment/stats-service -n ai-product-insights

# 4. Rollback si problème
kubectl rollout undo deployment/stats-service -n ai-product-insights
```

### Augmenter les ressources
```bash
# Éditer le deployment
kubectl edit deployment stats-service -n ai-product-insights

# Ou patch directement
kubectl patch deployment stats-service -n ai-product-insights --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"256Mi"}]'
```

### Exposer PostgreSQL en externe (debug only)
```bash
kubectl patch svc postgres-service -n ai-product-insights \
  -p '{"spec":{"type":"NodePort"}}'

# Récupérer le port
kubectl get svc postgres-service -n ai-product-insights
# Connecter: psql -h localhost -p <port>
```

---

## 📚 REFERENCES

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Kind Docs](https://kind.sigs.k8s.io/)
- [Nginx Ingress Docs](https://kubernetes.github.io/ingress-nginx/)
- [Kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**Dernière mise à jour**: Février 2026
**Kubernetes Version**: 1.20+
**Production Ready**: ✅ Oui (avec quelques ajouts: monitoring, backup)
