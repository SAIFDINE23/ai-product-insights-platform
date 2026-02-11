# 🔐 Kubernetes Secrets - Guide complet

## 📋 Vue d'ensemble

**Kubernetes Secrets** est la meilleure pratique pour stocker l'API Key Gemini en production:
- ✅ Chiffrement au repos (etcd)
- ✅ Accès contrôlé par RBAC
- ✅ Audit complet des accès
- ✅ Rotation facile
- ✅ Isolation par namespace
- ✅ Compatible avec tous les orchestrateurs

---

## 🚀 **MÉTHODE 1: Créer le Secret avec kubectl (Sécurisé - RECOMMANDÉ)**

### Étape 1: Créer le namespace
```bash
kubectl create namespace ai-product-insights
```

### Étape 2: Créer le Secret avec ta vraie clé (UNE SEULE FOIS)
```bash
# Replace AIza... avec ta vraie clé Gemini
kubectl create secret generic ai-analysis-secrets \
  --from-literal=GEMINI_API_KEY=AIza... \
  --from-literal=DB_USER=app_user \
  --from-literal=DB_PASSWORD=app_password \
  -n ai-product-insights
```

### Vérifier le Secret créé:
```bash
# Voir que le secret existe
kubectl get secrets -n ai-product-insights

# Voir les clés du secret (pas les valeurs)
kubectl describe secret ai-analysis-secrets -n ai-product-insights
```

### Décoder le Secret (pour vérifier - URGENT si erreur):
```bash
# ⚠️ NE FAIS CA QUE POUR DEBUG
kubectl get secret ai-analysis-secrets \
  -n ai-product-insights \
  -o jsonpath='{.data.GEMINI_API_KEY}' | base64 --decode
```

---

## 🔧 **MÉTHODE 2: Créer depuis un fichier YAML**

### ⚠️ IMPORTANT: Ne JAMAIS commiter la vraie clé!

**Option A: Fichier avec placeholder (safe to commit)**
```bash
# k8s/secrets.yaml existe déjà avec placeholder
# À utiliser avec Kustomize ou Helm pour injecter la vraie clé
cat k8s/secrets.yaml
```

**Option B: Générer depuis fichier .env (secure)**
```bash
# Créer un fichier temporaire .env (git-ignored)
cat > /tmp/secrets.env << 'EOF'
GEMINI_API_KEY=AIza...
DB_USER=app_user
DB_PASSWORD=app_password
EOF

# Créer le secret
kubectl create secret generic ai-analysis-secrets \
  --from-env-file=/tmp/secrets.env \
  -n ai-product-insights

# Nettoyer
rm /tmp/secrets.env
```

---

## 📦 **MÉTHODE 3: Avec Kustomize (Recommandé pour GitOps)**

Crée un fichier `k8s/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ai-product-insights

resources:
  - secrets.yaml
  - ai-analysis-service.yaml

# Remplacer les placeholders
replacements:
  - source:
      kind: ConfigMap
      name: env-config
      fieldPath: data.GEMINI_API_KEY
    targets:
      - select:
          kind: Secret
          name: ai-analysis-secrets
        fieldPath: stringData.GEMINI_API_KEY
```

Puis déployer:
```bash
kubectl apply -k k8s/
```

---

## 🔑 **MÉTHODE 4: Avec Sealed Secrets (Production Sécurisée)**

Pour une vraie sécurité production (la clé chiffrée reste dans git):

### 1. Installer Sealed Secrets:
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

### 2. Créer et sceller le secret:
```bash
# Créer secret temporaire
kubectl create secret generic ai-analysis-secrets \
  --from-literal=GEMINI_API_KEY=AIza... \
  -n ai-product-insights \
  --dry-run=client \
  -o yaml | kubectl seal -n ai-product-insights \
  -o yaml > k8s/ai-analysis-sealed-secret.yaml

# Le fichier peut maintenant être commité!
git add k8s/ai-analysis-sealed-secret.yaml
git commit -m "Add sealed secrets for AI analysis"
```

### 3. Déployer:
```bash
kubectl apply -f k8s/ai-analysis-sealed-secret.yaml
```

---

## 📝 **Vérifier que tout fonctionne**

### 1. ConfigMap créée?
```bash
kubectl get configmap -n ai-product-insights
kubectl describe configmap ai-analysis-config -n ai-product-insights
```

### 2. Secret créé?
```bash
kubectl get secret -n ai-product-insights
kubectl describe secret ai-analysis-secrets -n ai-product-insights
```

### 3. Pod est en running?
```bash
kubectl get pods -n ai-product-insights
kubectl logs -f deployment/ai-analysis-service -n ai-product-insights
```

### 4. Variables d'environnement chargées?
```bash
kubectl exec -it deployment/ai-analysis-service -n ai-product-insights -- env | grep GEMINI
```

---

## 🔄 **Mettre à jour la clé (Rotation)**

### Supprimer l'ancien secret:
```bash
kubectl delete secret ai-analysis-secrets -n ai-product-insights
```

### Créer le nouveau:
```bash
kubectl create secret generic ai-analysis-secrets \
  --from-literal=GEMINI_API_KEY=AIza_NOUVELLE_CLE \
  -n ai-product-insights
```

### Les pods se redémarrent automatiquement:
```bash
kubectl rollout restart deployment/ai-analysis-service \
  -n ai-product-insights
```

---

## 🛡️ **Sécurité - Bonnes Pratiques**

### ✅ À faire:
- ✅ Secrets chiffrés au repos (etcd encryption)
- ✅ RBAC limité pour lire les secrets
- ✅ Audit logging des accès aux secrets
- ✅ Rotation régulière des clés
- ✅ Secrets jamais en git (sauf Sealed Secrets)

### ❌ À NE PAS FAIRE:
- ❌ Commiter la vraie clé en git
- ❌ Hardcoder la clé en clair dans YAML
- ❌ Partager les secrets en Slack/Email
- ❌ Utiliser le même secret en dev et prod
- ❌ Ne pas logger les accès aux secrets

---

## 🔐 **Architecture: Flux du Secret**

```
┌─────────────────────────────────────┐
│ Google AI Studio                    │
│ → Générer API Key Gemini            │
└────────────────────┬────────────────┘
                     │ (AIza...)
                     ▼
        ┌────────────────────────┐
        │ Créer K8s Secret       │
        │ (kubectl create)       │
        └────────────┬───────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │ K8s etcd (chiffré)     │
        │ Stockage persistant    │
        └────────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
    ┌─────────────┐      ┌──────────────┐
    │ Deployment  │      │ Audit Logs   │
    │ ai-analysis │      │ (RBAC)       │
    └─────────────┘      └──────────────┘
         │
         ▼
    ┌──────────────┐
    │ Pod env var  │
    │ GEMINI_API_K │
    └──────────────┘
         │
         ▼
    ┌──────────────┐
    │ main.py      │
    │ genai.config │
    └──────────────┘
```

---

## 📚 **Fichiers K8s créés**

```
k8s/
├── secrets.yaml                 (Secrets + ConfigMap)
├── ai-analysis-service.yaml     (Deployment + Service + HPA)
└── kustomization.yaml           (À créer pour GitOps)
```

---

## 🚀 **Déployer tout en une commande**

### Option 1: kubectl direct
```bash
# 1. Créer le secret d'abord
kubectl create secret generic ai-analysis-secrets \
  --from-literal=GEMINI_API_KEY=AIza... \
  -n ai-product-insights

# 2. Créer ConfigMap
kubectl create configmap ai-analysis-config \
  --from-file=k8s/ai-analysis-config.env \
  -n ai-product-insights

# 3. Déployer l'application
kubectl apply -f k8s/ai-analysis-service.yaml
```

### Option 2: Kustomize (Meilleur)
```bash
kubectl apply -k k8s/
```

### Option 3: Helm (Plus flexible)
```bash
# À créer si tu veux
helm install ai-analysis ./helm/ai-analysis-service \
  --namespace ai-product-insights \
  --set geminiApiKey=AIza...
```

---

## ✅ Checklist

- [ ] K8s cluster accessible
- [ ] Namespace créé
- [ ] Secret créé (GEMINI_API_KEY)
- [ ] ConfigMap créé
- [ ] Deployment appliqué
- [ ] Pods en running
- [ ] Service accessible
- [ ] Logs sans erreurs

---

## 🔗 **Ressources**

- [K8s Secrets Docs](https://kubernetes.io/docs/concepts/configuration/secret/)
- [RBAC Best Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [HashiCorp Vault](https://www.vaultproject.io/)

---

## 📞 Prochaines étapes

1. **Obtenir ta clé Gemini** (si pas déjà fait)
2. **Créer le namespace K8s**
3. **Créer le secret** avec `kubectl create secret`
4. **Appliquer le deployment**
5. **Vérifier que tout fonctionne**

**Status: 🟢 Prêt pour production!**
