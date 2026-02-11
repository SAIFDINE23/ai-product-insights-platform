# AI Product Insights Platform - Dashboard React

## 🎯 Vue d'ensemble

Dashboard React professionnel pour visualiser en temps réel les statistiques d'analyse de sentiment et d'extraction de topics des avis clients.

## ✨ Fonctionnalités

### 1. Visualisation des Sentiments
- **Bar Chart interactif** avec Chart.js
- Distribution positive/neutral/negative
- Pourcentages calculés automatiquement
- Refresh automatique toutes les 30 secondes

### 2. Analyse des Topics
- Top 10 topics les plus fréquents
- Tableau avec ranking, count et pourcentage
- Barre de progression visuelle pour chaque topic
- Tri par fréquence décroissante

### 3. Statistiques Globales
- Nombre total de reviews analysées
- Compteurs par catégorie de sentiment
- Indicateurs visuels avec icônes SVG
- Design responsive (mobile/tablet/desktop)

### 4. Architecture Technique
- **Frontend**: React 18 + Vite
- **UI**: TailwindCSS (utility-first CSS)
- **Charts**: Chart.js + react-chartjs-2
- **API**: Fetch API vers Stats Service (port 8003)
- **Refresh**: Auto-refresh 30s + bouton manuel

## 📁 Structure du Projet

```
frontend/dashboard-react/
├── src/
│   ├── App.jsx           # Composant principal avec toute la logique
│   ├── main.jsx          # Point d'entrée React
│   └── index.css         # Styles TailwindCSS
├── public/               # Assets statiques
├── index.html            # Template HTML
├── package.json          # Dépendances npm
├── vite.config.js        # Configuration Vite
├── tailwind.config.js    # Configuration TailwindCSS
├── postcss.config.js     # PostCSS pour Tailwind
├── Dockerfile            # Image Docker (dev mode)
├── Dockerfile.production # Image Nginx (production)
└── nginx.conf            # Config Nginx pour SPA routing
```

## 🚀 Lancement Local

### Option 1: Docker Compose (Recommandé)
```bash
# Depuis la racine du projet
docker compose up -d dashboard-react

# Accéder au dashboard
open http://localhost:5173
```

### Option 2: npm (Développement)
```bash
cd frontend/dashboard-react

# Installer les dépendances
npm install

# Lancer le serveur de développement
npm run dev

# Le dashboard est disponible sur http://localhost:5173
```

## 🔧 Configuration

### Variables d'Environnement

Créer un fichier `.env` (optionnel):
```env
VITE_API_URL=http://localhost:8003
```

Par défaut, l'API URL est `http://localhost:8003` (Stats Service).

### Modification de l'URL API

Dans [App.jsx](./src/App.jsx#L60), ligne 60:
```javascript
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8003';
```

Pour Kubernetes, modifier avec:
```javascript
const API_BASE_URL = 'http://stats-service:8003';
```

## 📊 Endpoints API Utilisés

### 1. GET /stats/sentiment
**Récupère la distribution des sentiments**

Response:
```json
{
  "positive": 60,
  "neutral": 24,
  "negative": 16,
  "total": 100
}
```

### 2. GET /stats/topics?limit=10
**Récupère les top topics**

Response:
```json
[
  {"topic": "highly_satisfied", "count": 40},
  {"topic": "performance", "count": 12},
  {"topic": "quality", "count": 11}
]
```

## 🐳 Déploiement Docker

### Mode Développement (avec Hot Reload)
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev"]
```

Build & Run:
```bash
docker build -t dashboard-react:dev .
docker run -p 5173:5173 dashboard-react:dev
```

### Mode Production (Nginx)
```dockerfile
# Stage 1: Build React
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve avec Nginx
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build & Run:
```bash
docker build -f Dockerfile.production -t dashboard-react:prod .
docker run -p 80:80 dashboard-react:prod
```

## ☸️ Déploiement Kubernetes

### Deployment YAML
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard-react
  namespace: ai-product-insights
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dashboard-react
  template:
    metadata:
      labels:
        app: dashboard-react
    spec:
      containers:
      - name: frontend
        image: saifdine23/frontend:latest
        ports:
        - containerPort: 5173
        env:
        - name: VITE_API_URL
          value: "http://stats-service:8003"
        livenessProbe:
          httpGet:
            path: /
            port: 5173
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 5173
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Service YAML
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dashboard-react
  namespace: ai-product-insights
spec:
  selector:
    app: dashboard-react
  ports:
  - port: 5173
    targetPort: 5173
  type: ClusterIP
```

### Ingress YAML
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ai-product-insights-ingress
  namespace: ai-product-insights
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dashboard-react
            port:
              number: 5173
```

Appliquer les manifests:
```bash
kubectl apply -f infra/kubernetes/
kubectl get pods -n ai-product-insights
kubectl port-forward svc/dashboard-react 5173:5173 -n ai-product-insights
```

## 📦 Build Production

### Build local
```bash
npm run build

# Les fichiers sont générés dans dist/
ls -la dist/
```

### Build avec Docker
```bash
docker build -f Dockerfile.production -t saifdine23/frontend:latest .
docker push saifdine23/frontend:latest
```

### Build avec CI/CD (GitHub Actions)
Le workflow `.github/workflows/ci-cd.yml` build automatiquement:
```yaml
- name: Build Frontend
  uses: docker/build-push-action@v5
  with:
    context: frontend/dashboard-react
    tags: |
      saifdine23/frontend:latest
      saifdine23/frontend:${{ github.sha }}
    push: true
```

## 🎨 Personnalisation

### Modifier les Couleurs
Dans [App.jsx](./src/App.jsx#L145), lignes 145-160:
```javascript
backgroundColor: [
  'rgba(34, 197, 94, 0.8)',   // Vert pour positive
  'rgba(59, 130, 246, 0.8)',  // Bleu pour neutral
  'rgba(239, 68, 68, 0.8)',   // Rouge pour negative
]
```

### Changer l'Interval de Refresh
Dans [App.jsx](./src/App.jsx#L126), ligne 126:
```javascript
const interval = setInterval(() => {
  loadData();
}, 30000); // 30 secondes -> modifier ici
```

### Ajouter des Graphiques
Installer d'autres charts:
```bash
npm install react-chartjs-2 chart.js
```

Importer dans App.jsx:
```javascript
import { Line, Pie, Doughnut } from 'react-chartjs-2';
```

## 🧪 Tests

### Test Manuel
```bash
# Vérifier que le frontend répond
curl http://localhost:5173

# Tester la connexion API
curl http://localhost:8003/stats/sentiment
curl http://localhost:8003/stats/topics?limit=5
```

### Test dans le Navigateur
1. Ouvrir http://localhost:5173
2. Vérifier la console pour les erreurs
3. Cliquer sur "Refresh" pour tester le chargement manuel
4. Vérifier que les données se mettent à jour

### Test de Production
```bash
# Build production
npm run build

# Servir avec nginx local
npm run preview
```

## 🔍 Débogage

### Logs Docker Compose
```bash
docker compose logs dashboard-react -f
```

### Logs Kubernetes
```bash
kubectl logs deployment/dashboard-react -n ai-product-insights
kubectl describe pod <pod-name> -n ai-product-insights
```

### Erreurs Fréquentes

**1. CORS Error**
- Vérifier que `CORSMiddleware` est activé dans Stats Service
- Vérifier l'URL de l'API dans App.jsx

**2. Failed to fetch**
- Vérifier que Stats Service est démarré: `docker compose ps`
- Tester l'API directement: `curl http://localhost:8003/stats/sentiment`

**3. Empty data / No charts**
- Vérifier que reviews_analysis contient des données
- Tester les endpoints API manuellement

## 📚 Ressources

- [React Documentation](https://react.dev)
- [Vite Documentation](https://vitejs.dev)
- [TailwindCSS](https://tailwindcss.com)
- [Chart.js](https://www.chartjs.org)
- [Docker Documentation](https://docs.docker.com)
- [Kubernetes Documentation](https://kubernetes.io/docs)

## 👨‍💻 Développement

### Contribuer
1. Fork le projet
2. Créer une branche: `git checkout -b feature/nouvelle-fonctionnalite`
3. Commit: `git commit -m 'Ajout nouvelle fonctionnalité'`
4. Push: `git push origin feature/nouvelle-fonctionnalite`
5. Créer une Pull Request

### Standards de Code
- ESLint configuré avec React best practices
- Format avec Prettier
- Commits conventionnels (feat, fix, docs, etc.)

## 📄 Licence

MIT License - Voir [LICENSE](../../LICENSE) pour plus de détails.

---

**AI Product Insights Platform** - Dashboard professionnel pour l'analyse de sentiment client
