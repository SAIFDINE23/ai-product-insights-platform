# 🚀 Migration VADER → Gemini API - Résumé des changements

## 📝 Vue d'ensemble

Le service `ai-analysis-service` a été migré de **VADER** (analyse de sentiment basée sur des mots-clés) vers **Google Gemini API** (IA générative) pour une analyse plus professionnelle et contextuelle.

---

## 🔄 Changements apportés

### 1. **backend/ai-analysis-service/main.py**

#### Avant (VADER):
```python
from nltk.sentiment import SentimentIntensityAnalyzer
import nltk

nltk.download('vader_lexicon', download_dir='/tmp/nltk_data')
sia = SentimentIntensityAnalyzer()

def analyze_sentiment(text: str) -> dict:
    scores = sia.polarity_scores(text)
    # ... retournait scores VADER
```

#### Après (Gemini):
```python
import google.generativeai as genai
import json

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)
MODEL_NAME = "gemini-2.0-flash"

def analyze_sentiment(text: str) -> dict:
    prompt = f"""Analyze sentiment of: {text}
    Return JSON with: sentiment, score, confidence, summary
    """
    response = genai.GenerativeModel(MODEL_NAME).generate_content(prompt)
    result = json.loads(response.text)
    # ... retourne réponse Gemini
```

### 2. **backend/ai-analysis-service/requirements.txt**

```diff
- nltk==3.8.1
+ google-generativeai==0.8.3
```

### 3. **backend/ai-analysis-service/.env.example** (Nouveau)

```bash
GEMINI_API_KEY=your_gemini_api_key_here
```

### 4. **backend/ai-analysis-service/README.md** (Nouveau)

Documentation complète sur:
- Comment obtenir une clé API Gemini
- Configuration d'environnement
- Architecture et endpoints
- Troubleshooting

### 5. **ci-cd/configure-gemini.sh** (Nouveau script)

Automatise la configuration de la clé Gemini dans Jenkins:
```bash
./ci-cd/configure-gemini.sh
```

### 6. **GEMINI_SETUP.md** (Nouveau)

Guide complet pour configurer Gemini dans Jenkins et Kubernetes.

---

## ✨ Améliorations

### Avant (VADER):
- ❌ Analyse basée sur dictionnaire fixe
- ❌ Peu de contexte (mots-clés uniquement)
- ❌ Topics extraits par regex
- ❌ Offline uniquement
- ❌ Pas de résumé explicatif

### Après (Gemini):
- ✅ Compréhension contextuelle profonde
- ✅ Analyse sémantique (IA)
- ✅ Extraction de topics intelligente
- ✅ Fallback automatique si API échoue
- ✅ Résumé explicatif généré
- ✅ Score de confiance
- ✅ Réponses naturelles en langage

---

## 📊 Exemple de réponse

### Avant (VADER):
```json
{
  "sentiment": "positive",
  "score": 0.789,
  "details": {
    "positive": 0.789,
    "negative": 0.0,
    "neutral": 0.211
  }
}
```

### Après (Gemini):
```json
{
  "sentiment": "positive",
  "sentiment_score": 0.92,
  "confidence": 0.95,
  "summary": "Le client est très satisfait du produit, apprécie la qualité et la performance",
  "topics": ["quality", "performance", "highly_satisfied"],
  "details": {
    "positive": 1.0,
    "negative": 0.0,
    "neutral": 0.0
  }
}
```

---

## 🔧 Configuration requise

### Seul requis: Une clé API Gemini

**Obtenir la clé:**
1. Allez sur https://aistudio.google.com/app/apikeys
2. Cliquez "Create API Key"
3. Copiez la clé (commence par `AIza...`)

**Ajouter dans Jenkins:**
```bash
cd ci-cd/
./configure-gemini.sh
# Entrez votre clé API
```

Ou manuellement:
1. Jenkins → Manage Jenkins → Credentials
2. Add Credentials → Secret text
3. ID: `gemini-api-key`
4. Collez votre clé

---

## 📦 Dépendances

### Ajoutées:
```
google-generativeai==0.8.3
```

### Supprimées:
```
nltk==3.8.1
```

### Inchangées:
```
fastapi==0.111.0
uvicorn[standard]==0.30.1
psycopg2-binary==2.9.9
pydantic==2.6.3
```

---

## 🚀 Prochaines étapes pour la mise en prod

### 1. **Obtenir la clé Gemini** (5 min)
```bash
# Allez sur https://aistudio.google.com/app/apikeys
# Cliquez "Create API Key"
# Copiez-la
```

### 2. **Configurer Jenkins** (2 min)
```bash
cd /home/saif/projects/Product_Insights/ci-cd
./configure-gemini.sh
# Entrez votre clé API
```

### 3. **Committer les changements** (1 min)
```bash
cd /home/saif/projects/Product_Insights
git add backend/ai-analysis-service/
git add GEMINI_SETUP.md
git add ci-cd/configure-gemini.sh
git commit -m "feat: Replace VADER with Gemini API for AI analysis"
git push
```

### 4. **Rebuilder les images** (5-10 min)
- Jenkins → Build Now
- Attendez que le pipeline réussisse

### 5. **Tester le service** (1 min)
```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "review_text": "Produit extraordinaire, très satisfait!",
    "rating": 5
  }'
```

---

## 🔒 Sécurité

### Bonnes pratiques appliquées:

✅ **Secrets Jenkins**
- Clé API stockée comme credential (pas en git)
- Accessible seulement aux pipelines autorisés

✅ **Variables d'environnement**
- Jamais hardcodée dans le code
- Chargée à runtime depuis l'environnement

✅ **Fallback sécurisé**
- Si API Gemini échoue, analyse par mots-clés activée
- Service continue de fonctionner

✅ **.gitignore**
- `.env` local ignoré
- Pas de secrets en git

---

## 💰 Coût

**Google Gemini API:**
- FREE: 15 appels/minute, 1M tokens/jour
- Quota suffisant pour tester et développer
- Production: Vérifiez https://ai.google.dev/pricing

**Comparaison VADER vs Gemini:**
- VADER: Offline, libre, basique
- Gemini: IA avancée, peu coûteux, professionnel

---

## ⚠️ Fallback automatique

Si l'API Gemini échoue (réseau, quota, erreur):
```python
# Le service bascule automatiquement vers:
# - Analyse par mots-clés (fallback)
# - Extraction de topics simple
# Service continue de fonctionner sans interruption
```

---

## 📚 Fichiers modifiés

| Fichier | Type | Description |
|---------|------|-------------|
| `backend/ai-analysis-service/main.py` | Modifié | Remplacer VADER par Gemini |
| `backend/ai-analysis-service/requirements.txt` | Modifié | Ajouter google-generativeai |
| `backend/ai-analysis-service/.env.example` | Nouveau | Template de configuration |
| `backend/ai-analysis-service/README.md` | Nouveau | Documentation du service |
| `ci-cd/configure-gemini.sh` | Nouveau | Script de configuration Jenkins |
| `GEMINI_SETUP.md` | Nouveau | Guide complet de setup |

---

## ✅ Checklist de vérification

- [ ] Clé API Gemini obtenue
- [ ] `./configure-gemini.sh` exécuté avec succès
- [ ] Changements committés et pushés
- [ ] Pipeline de build réussi
- [ ] Images Docker reconstruites
- [ ] Service testable via `/health`
- [ ] Endpoint `/analyze` fonctionnel
- [ ] Réponses Gemini correctes

---

## 🆘 Troubleshooting

### "GEMINI_API_KEY environment variable not set"
```bash
# Vérifier que Jenkins credential est configurée
# Jenkins → Manage Jenkins → Credentials
# ID doit être: gemini-api-key
```

### "Invalid API key"
```bash
# Vérifier la clé sur https://aistudio.google.com/app/apikeys
# Copier exactement (pas d'espaces)
```

### Analyse lente (2-3 secondes)
```bash
# Normal: API Gemini en ligne
# Si problématique: passer à gemini-1.5-flash (plus rapide)
# Modifier MODEL_NAME dans main.py
```

---

## 📞 Support

- **Documentation API Gemini**: https://ai.google.dev/docs
- **Tarification**: https://ai.google.dev/pricing
- **Studio**: https://aistudio.google.com
- **Python SDK**: https://github.com/google/generative-ai-python

---

**Statut**: ✅ Prêt pour production après obtention de la clé API Gemini
