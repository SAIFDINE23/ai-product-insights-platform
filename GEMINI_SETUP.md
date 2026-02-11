# Configuration des secrets Gemini pour le Pipeline Jenkins

## 📋 Résumé

Le service `ai-analysis-service` utilise maintenant **Google Gemini API** pour une analyse professionnelle. Il faut configurer la clé API Gemini comme secret Jenkins.

## 🔧 Configuration dans Jenkins

### Option 1: Via Jenkins Credentials (Recommandé pour Production)

1. **Allez dans Jenkins UI**
   - URL: `http://localhost:8080`
   - Menu: Manage Jenkins → Credentials → System → Global credentials

2. **Créer une nouvelle credential**
   - Click "Add Credentials"
   - Kind: `Secret text`
   - Secret: `votre_clé_api_gemini`
   - ID: `gemini-api-key` (important!)
   - Description: `Google Gemini API Key`

3. **Utiliser dans le Jenkinsfile**
   ```groovy
   withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
       // Le service utilisera cette variable
   }
   ```

### Option 2: Via fichier .env

1. **Créer un fichier .env dans chaque service**
   ```bash
   echo "GEMINI_API_KEY=votre_clé_api_gemini" > backend/ai-analysis-service/.env
   ```

2. **Le Dockerfile charge la variable**
   ```dockerfile
   RUN cat .env >> /etc/environment || true
   ```

### Option 3: Via Docker Compose (Local Development)

```yaml
services:
  ai-analysis-service:
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY}
```

Puis lancer avec:
```bash
export GEMINI_API_KEY="votre_clé_api_gemini"
docker-compose up
```

## 🔑 Obtenir une clé API Gemini

### Étapes:

1. **Accédez à Google AI Studio**
   - URL: https://aistudio.google.com/app/apikeys

2. **Authentifiez-vous avec votre compte Google**

3. **Cliquez sur "Create API Key"**
   - Sélectionnez le projet (créez un nouveau projet si nécessaire)
   - Une clé sera générée automatiquement

4. **Copiez la clé**
   - Format: `AIzaSyD...` (longue chaîne de caractères)

5. **Ne la partagez PAS**
   - Utilisez des secrets Jenkins pour la sécurité
   - Ne commandez PAS le .env avec la clé en git

## 🛡️ Sécurité

### Ne JAMAIS:
❌ Committer la clé API en git
❌ La mettre en dur dans le code
❌ La partager en message

### À FAIRE:
✅ Utiliser Jenkins Credentials (Secret text)
✅ Utiliser des variables d'environnement
✅ Lire depuis des fichiers .env (git ignorés)
✅ Limiter l'accès à la clé dans Jenkins

## 📝 Exemple de configuration Jenkins

Ajoutez ceci à votre Jenkinsfile si vous utilisez des credentials:

```groovy
pipeline {
    agent any
    
    environment {
        REGISTRY = "docker.io"
        DOCKER_REPO = "saifdine23"
    }
    
    stages {
        stage('Build Services') {
            steps {
                script {
                    // Utiliser les credentials Gemini
                    withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
                        sh '''
                            cd backend/ai-analysis-service
                            docker build \
                                --build-arg GEMINI_API_KEY=${GEMINI_API_KEY} \
                                -t ${DOCKER_REPO}/ai-analysis-service:latest .
                        '''
                    }
                }
            }
        }
    }
}
```

## 🚀 Déploiement en Kubernetes

Pour Kubernetes, utilisez Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ai-analysis-secrets
  namespace: ai-product-insights
type: Opaque
stringData:
  GEMINI_API_KEY: "votre_clé_api_gemini"
---
apiVersion: v1
kind: Pod
metadata:
  name: ai-analysis-service
spec:
  containers:
  - name: ai-analysis
    image: saifdine23/ai-analysis-service:latest
    env:
    - name: GEMINI_API_KEY
      valueFrom:
        secretKeyRef:
          name: ai-analysis-secrets
          key: GEMINI_API_KEY
```

Puis appliquez:
```bash
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/ai-analysis-service.yaml
```

## ✅ Vérification

Pour vérifier que tout fonctionne:

```bash
# Test local
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Ce produit est incroyable!",
    "rating": 5
  }'

# Vous devriez obtenir:
# {
#   "sentiment": "positive",
#   "sentiment_score": 0.95,
#   "topics": ["highly_satisfied"],
#   "details": {...}
# }
```

## 💰 Tarification

Gemini API est FREE avec des quotas:
- 15 appels par minute (free tier)
- 1 million tokens par jour (gratuit)

Pour la production avec plus d'appels, consultez: https://ai.google.dev/pricing

## 📚 Ressources

- [Google AI Studio](https://aistudio.google.com)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Python SDK](https://github.com/google/generative-ai-python)
- [Pricing](https://ai.google.dev/pricing)

## ❓ FAQ

**Q: Puis-je utiliser une clé gratuite?**
R: Oui, Google fournit un quota gratuit suffisant pour tester et développer.

**Q: Dois-je créer un projet Google Cloud?**
R: Non, vous pouvez utiliser Google AI Studio directement (plus simple).

**Q: Que se passe-t-il si l'API Gemini échoue?**
R: Le service a un fallback automatique qui utilise l'analyse par mots-clés.

**Q: Comment vérifier ma consommation d'tokens?**
R: Allez sur https://ai.google.dev/account et vérifiez votre quota.
