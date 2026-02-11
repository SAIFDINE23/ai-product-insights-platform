# 🚀 JENKINS CI/CD SETUP GUIDE

> **Expert DevOps Jenkins Setup** - Production-Ready Configuration

## 📋 TABLE DES MATIÈRES

1. [Configuration Rapide](#configuration-rapide)
2. [Prérequis](#prérequis)
3. [Installation Détaillée](#installation-détaillée)
4. [Configuration Jenkins](#configuration-jenkins)
5. [Création du Pipeline](#création-du-pipeline)
6. [Utilisation](#utilisation)
7. [Troubleshooting](#troubleshooting)

---

## 🚀 CONFIGURATION RAPIDE

```bash
cd /home/saif/projects/Product_Insights

# 1. Démarrer Jenkins
chmod +x ci-cd/start-jenkins.sh
./ci-cd/start-jenkins.sh

# 2. Attendre 60 secondes
# Jenkins démarre à http://localhost:8080

# 3. Configurer les credentials
chmod +x ci-cd/configure-credentials.sh
./ci-cd/configure-credentials.sh
```

**C'est tout!** Jenkins est prêt pour les builds. ✅

---

## 📦 PRÉREQUIS

### Système
- **Linux/Mac/Windows (WSL2)**
- **Docker** ≥ 20.10
- **Docker Compose** ≥ 2.0
- **8GB RAM minimum** (recommandé 16GB)
- **10GB disque libre**

### Comptes
- **DockerHub** - pour push des images
  - Username
  - Password ou Personal Access Token
- **GitHub** (optionnel) - si repo privé
  - GitHub Token

### Outils (automatiquement installés par Jenkins)
- Docker CLI
- kubectl
- Trivy
- Helm
- Kind

---

## 📝 INSTALLATION DÉTAILLÉE

### **Étape 1: Préparer les fichiers**

Les fichiers suivants doivent être présents dans `ci-cd/`:
```
ci-cd/
├── docker-compose.jenkins.yml    # Configuration Docker Compose
├── Dockerfile.jenkins             # Image Jenkins custom
├── plugins.txt                    # Liste des plugins
├── init.groovy.d/
│   └── security.groovy           # Configuration Groovy
├── start-jenkins.sh              # Script de démarrage
└── configure-credentials.sh       # Script de configuration
```

Vérifiez:
```bash
ls -la ci-cd/
```

### **Étape 2: Lancer Jenkins**

```bash
cd ci-cd
chmod +x start-jenkins.sh
./start-jenkins.sh
```

**Sortie attendue:**
```
════════════════════════════════════════════════════════
DÉMARRAGE JENKINS
════════════════════════════════════════════════════════
✓ Docker installé
✓ Docker Compose installé
✓ Docker daemon en cours d'exécution
✓ Répertoires créés
✓ Jenkins démarré
Attente du démarrage de Jenkins (cela peut prendre 60 secondes)...
✓ Jenkins est prêt!

════════════════════════════════════════════════════════
✓ JENKINS DÉMARRÉ AVEC SUCCÈS!
════════════════════════════════════════════════════════

INFORMATIONS D'ACCÈS:
  URL: http://localhost:8080
  Utilisateur: admin
  Mot de passe: admin
```

### **Étape 3: Accéder à Jenkins**

Ouvrez votre navigateur:
```
http://localhost:8080
```

Login:
- **Username:** `admin`
- **Password:** `admin`

### **Étape 4: Configurer les Credentials**

```bash
chmod +x configure-credentials.sh
./configure-credentials.sh
```

Le script vous demandera:
```
DockerHub Username: saifdine23
DockerHub Password/Token: your_token_here
GitHub URL (optionnel): https://github.com/your-repo
GitHub Token (optionnel): your_github_token
```

---

## ⚙️ CONFIGURATION JENKINS

### **Configuration Automatique (Déjà effectuée)**

Le `Dockerfile.jenkins` installe automatiquement:
- ✅ Docker CLI
- ✅ Trivy (security scanning)
- ✅ kubectl (Kubernetes deployment)
- ✅ Helm (package management)
- ✅ Kind (local K8s)
- ✅ 40+ plugins Jenkins

### **Vérifier l'Installation des Plugins**

1. Allez sur `http://localhost:8080`
2. Menu **Manage Jenkins** > **Manage Plugins**
3. Vérifiez que les plugins sont "Installed and enabled":
   - Pipeline
   - Docker
   - Kubernetes
   - Git
   - GitHub
   - Slack (optionnel)

### **Configurer les Credentials (UI)**

1. **Manage Jenkins** > **Manage Credentials**
2. **Global credentials** > **Add Credentials**

#### **DockerHub Credentials**
- Kind: **Username with password**
- Username: `saifdine23`
- Password: `your_dockerhub_token`
- ID: `dockerhub-credentials`
- Description: `DockerHub Credentials`

#### **GitHub Credentials** (optionnel)
- Kind: **Username with password**
- Username: `your-github-username`
- Password: `your-github-token`
- ID: `github-credentials`
- Description: `GitHub Credentials`

#### **Kubernetes Credentials** (si déploiement K8s)
- Kind: **Kubernetes configuration (kubeconfig)**
- Kubeconfig: (contenu de `~/.kube/config`)
- ID: `kubeconfig`

---

## 🔧 CRÉATION DU PIPELINE

### **Option 1: Pipeline Job from SCM** (Recommandé)

1. **New Item**
2. Entrez le nom: `AI-Product-Insights`
3. Sélectionnez: **Pipeline**
4. Cliquez: **OK**

### **Configuration du Pipeline**

**Onglet: General**
- ✅ Discard old builds: 30 items

**Onglet: Pipeline**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/your-username/Product_Insights`
- Credentials: (laissez vide si public, sinon sélectionnez GitHub credentials)
- Branch: `*/main`
- Script Path: `Jenkinsfile`

**Sauvegardez et testez:**
```bash
# Lancer le build
Build Now
```

### **Option 2: Déclaration Inline (Testing)**

Si vous voulez tester sans Git:

1. **New Item** > **Pipeline**
2. **Onglet: Pipeline**
3. Definition: **Pipeline script**
4. Copiez le contenu du `Jenkinsfile` dans le script

---

## 📊 UTILISATION

### **Lancer un Build**

```bash
# Via UI
1. Allez sur http://localhost:8080
2. Cliquez sur le job: AI-Product-Insights
3. Build Now

# Via CLI
curl -X POST http://admin:admin@localhost:8080/job/AI-Product-Insights/build
```

### **Personnaliser le Build**

Le pipeline supporte des **parameters**:

1. **ACTION:**
   - `Build & Push` - Build + Push images (par défaut)
   - `Build & Push & Deploy` - + Déployer sur K8s

2. **IMAGE_TAG:**
   - `latest` (défaut)
   - `v1.0.0`
   - `dev`
   - Votre tag personnalisé

3. **Flags:**
   - `PUSH_TO_REGISTRY` - Push les images?
   - `SCAN_WITH_TRIVY` - Scanner les vulnérabilités?

### **Build Personnalisé**

```bash
curl -X POST \
  'http://admin:admin@localhost:8080/job/AI-Product-Insights/buildWithParameters' \
  -d 'ACTION=Build+%26+Push+%26+Deploy' \
  -d 'IMAGE_TAG=v1.0.0' \
  -d 'PUSH_TO_REGISTRY=true' \
  -d 'SCAN_WITH_TRIVY=true'
```

### **Voir les Logs**

```bash
# Logs du dernier build
curl -s http://admin:admin@localhost:8080/job/AI-Product-Insights/lastBuild/consoleText | less

# Logs du container Jenkins
docker-compose -f docker-compose.jenkins.yml logs -f jenkins
```

---

## 📈 CE QUE LE PIPELINE FAIT

```
┌─────────────────────────────────────────┐
│ 1. CHECKOUT                              │
│    Git clone le repo                     │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│ 2. VERIFY PREREQUISITES                  │
│    Docker, Trivy, kubectl, Git           │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│ 3. BUILD DOCKER IMAGES (Parallèle)       │
│    ✓ scraper-service                    │
│    ✓ ai-analysis-service                │
│    ✓ stats-service                      │
│    ✓ dashboard-frontend                 │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│ 4. SECURITY SCAN WITH TRIVY              │
│    Scan chaque image pour vulnérabilités │
│    (Si SCAN_WITH_TRIVY=true)             │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│ 5. PUSH TO DOCKERHUB                     │
│    docker push each image                │
│    (Si PUSH_TO_REGISTRY=true)            │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│ 6. DEPLOY TO KUBERNETES                  │
│    kubectl apply -f k8s/                 │
│    (Si ACTION="Build & Push & Deploy")   │
└─────────────────────────────────────────┘
```

---

## 🔍 MONITORING & LOGS

### **Accéder à Jenkins**
```bash
# UI Web
http://localhost:8080

# API Jenkins
curl -s http://admin:admin@localhost:8080/api/json | jq

# Système d'info
curl -s http://admin:admin@localhost:8080/systemInfo
```

### **Logs des Builds**

```bash
# Dernier build
curl -s http://admin:admin@localhost:8080/job/AI-Product-Insights/lastBuild/consoleText

# Build spécifique (#5)
curl -s http://admin:admin@localhost:8080/job/AI-Product-Insights/5/consoleText

# JSON du build
curl -s http://admin:admin@localhost:8080/job/AI-Product-Insights/lastBuild/api/json | jq
```

### **Logs du Container Jenkins**

```bash
# Logs en temps réel
docker-compose -f docker-compose.jenkins.yml logs -f jenkins

# Dernières 100 lignes
docker-compose -f docker-compose.jenkins.yml logs -n 100 jenkins

# Avec timestamps
docker-compose -f docker-compose.jenkins.yml logs --timestamps jenkins
```

---

## 🛠️ TROUBLESHOOTING

### **Jenkins ne démarre pas**

```bash
# Vérifiez les logs
docker-compose -f docker-compose.jenkins.yml logs jenkins

# Port 8080 occupé?
lsof -i :8080
killall java  # Si nécessaire

# Redémarrez
docker-compose -f docker-compose.jenkins.yml restart jenkins
```

### **Docker socket non accessible**

```bash
# Vérifiez les permissions
ls -la /var/run/docker.sock

# Redémarrez Docker
sudo systemctl restart docker

# Redémarrez Jenkins
docker-compose -f docker-compose.jenkins.yml restart jenkins
```

### **Credentials non trouvés**

```bash
# Re-configurer
./configure-credentials.sh

# Ou via UI: Manage Jenkins > Manage Credentials
```

### **Build échoue sur "Push to Registry"**

```bash
# Vérifiez les credentials DockerHub
docker login -u saifdine23

# Testez manuellement
docker push saifdine23/scraper-service:latest

# Vérifiez le Jenkinsfile - 'dockerhub-credentials' doit correspondre
```

### **Images ne se pushent pas**

```bash
# Vérifiez que les images sont construites
docker images | grep saifdine23

# Build manuellement pour tester
cd backend/scraper-service
docker build -t saifdine23/scraper-service:latest .
docker push saifdine23/scraper-service:latest
```

---

## 📋 CHECKLIST POST-INSTALLATION

- [ ] Jenkins démarre sans erreurs
- [ ] Accès à http://localhost:8080 avec admin/admin
- [ ] Credentials DockerHub configurées
- [ ] Pipeline job "AI-Product-Insights" créé
- [ ] Build réussit sans erreurs
- [ ] Images poussées vers DockerHub
- [ ] (Optionnel) Déploiement K8s fonctionne

---

## 🚀 PROCHAINES ÉTAPES

### **Court terme (aujourd'hui)**
1. ✅ Jenkins en cours d'exécution
2. ✅ Credentials configurées
3. ✅ Pipeline testé
4. Build manuel réussi

### **Moyen terme (cette semaine)**
1. Intégrer GitHub Webhooks (push automatique → build)
2. Ajouter tests unitaires au pipeline
3. Configurer notifications Slack
4. Sauvegarder la configuration Jenkins

### **Long terme (ce mois)**
1. Multi-stage deployments (dev → staging → prod)
2. ArgoCD pour GitOps
3. Monitoring des builds (Prometheus + Grafana)
4. Backup automatique Jenkins

---

## 📚 RESSOURCES

- [Jenkins Official Docs](https://www.jenkins.io/doc/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Docker plugin for Jenkins](https://plugins.jenkins.io/docker-plugin/)
- [Kubernetes plugin for Jenkins](https://plugins.jenkins.io/kubernetes/)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)

---

## 📞 SUPPORT

Pour toute question:
1. Vérifiez les logs: `docker-compose logs jenkins`
2. Consultez la section Troubleshooting
3. Relancez le script de démarrage

---

**Status:** ✅ Production-Ready
**Version:** 1.0.0
**Last Updated:** February 2026
