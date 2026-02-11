# 🚀 CI/CD JENKINS - README

> Expert DevOps Setup - Production Ready

## ⚡ Quick Start (3 minutes)

```bash
# 1. Navigate to project
cd /home/saif/projects/Product_Insights

# 2. Start Jenkins (60 seconds)
./ci-cd/start-jenkins.sh

# 3. Configure credentials
./ci-cd/configure-credentials.sh

# 4. Open http://localhost:8080
# Login: admin / admin
```

---

## 📦 What's Inside

### Core Files

| File | Size | Purpose |
|------|------|---------|
| `docker-compose.jenkins.yml` | 2.6K | Jenkins + Docker socket setup |
| `Dockerfile.jenkins` | 4.3K | Custom Jenkins image (Docker, Trivy, kubectl, Helm, Kind) |
| `plugins.txt` | 3.1K | 40+ Jenkins plugins pre-configured |
| `Jenkinsfile` | 18K | Full CI/CD pipeline declaration |
| `init.groovy.d/security.groovy` | 1.5K | Auto Jenkins configuration |

### Scripts

| Script | Size | Purpose |
|--------|------|---------|
| `start-jenkins.sh` | 4.8K | Launch Jenkins + health checks |
| `configure-credentials.sh` | 5.2K | Interactive credentials setup |

### Documentation

| Doc | Size | Purpose |
|-----|------|---------|
| `JENKINS-SETUP.md` | 13K | Complete setup guide |
| `README.md` | This file | Quick reference |

### Security

| File | Purpose |
|------|---------|
| `.gitignore` | Don't commit secrets |

**Total Size:** 64KB (+ Jenkinsfile 18KB at root)

---

## 🎯 Pipeline Stages

```
1. ✓ CHECKOUT (Git clone)
    └─ Verify commit info, author, message

2. ✓ VERIFY PREREQUISITES 
    └─ Docker, Trivy, kubectl, Git versions

3. ✓ BUILD DOCKER IMAGES (Parallel - 4 services)
    ├─ scraper-service
    ├─ ai-analysis-service
    ├─ stats-service
    └─ dashboard-frontend

4. ✓ SECURITY SCAN (Trivy)
    ├─ Scan scraper (HIGH,CRITICAL)
    ├─ Scan ai-analysis
    ├─ Scan stats
    └─ Scan frontend

5. ✓ PUSH TO DOCKERHUB
    ├─ Login docker
    ├─ Push all images
    └─ Logout

6. ✓ DEPLOY TO KUBERNETES (Optional)
    └─ kubectl apply -f k8s/
```

---

## 🔧 Parameters

Build with custom parameters:

```groovy
ACTION              // "Build & Push" (default) or "Build & Push & Deploy"
IMAGE_TAG           // "latest" (default) or "v1.0.0" or custom tag
PUSH_TO_REGISTRY    // true/false
SCAN_WITH_TRIVY     // true/false
```

**Example:**
```bash
# Build only
ACTION=Build & Push
IMAGE_TAG=latest

# Build + Deploy to K8s
ACTION=Build & Push & Deploy
IMAGE_TAG=v1.0.0
PUSH_TO_REGISTRY=true
SCAN_WITH_TRIVY=true
```

---

## 📋 Setup Steps

### Step 1: Start Jenkins

```bash
./ci-cd/start-jenkins.sh
```

**Output:**
```
✓ Docker found
✓ Docker Compose found
✓ Docker daemon running
✓ Jenkins started
✓ Jenkins is ready!

URL: http://localhost:8080
Username: admin
Password: admin
```

### Step 2: First Login

- Open: http://localhost:8080
- Login: admin / admin
- Skip the setup wizard (already configured)

### Step 3: Configure Credentials

```bash
./ci-cd/configure-credentials.sh
```

**Interactive prompts:**
```
DockerHub Username: saifdine23
DockerHub Password/Token: your_token_here
GitHub URL (optional): https://github.com/your-repo
GitHub Token (optional): your_token_here
```

### Step 4: Create Pipeline Job (UI)

1. **New Item**
2. Name: `AI-Product-Insights`
3. Type: **Pipeline**
4. Click **OK**

**Configuration:**

In **Pipeline** section:
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/your-repo/Product_Insights`
- Credentials: (select if private repo)
- Branch: `*/main`
- Script Path: `Jenkinsfile`

Click **Save**

### Step 5: Build

1. Go to job page
2. Click **Build Now**
3. Watch logs in real-time
4. Check Docker images on DockerHub

---

## 🔍 Commands

### Jenkins Management

```bash
# View logs
docker-compose -f ci-cd/docker-compose.jenkins.yml logs -f jenkins

# Stop Jenkins
docker-compose -f ci-cd/docker-compose.jenkins.yml down

# Restart Jenkins
docker-compose -f ci-cd/docker-compose.jenkins.yml restart jenkins

# Clean all data
docker-compose -f ci-cd/docker-compose.jenkins.yml down -v
```

### Jenkins API

```bash
# List all jobs
curl -s http://admin:admin@localhost:8080/api/json | jq '.jobs[].name'

# Get last build info
curl -s http://admin:admin@localhost:8080/job/AI-Product-Insights/lastBuild/api/json | jq

# Trigger build
curl -X POST http://admin:admin@localhost:8080/job/AI-Product-Insights/build

# Build with parameters
curl -X POST \
  'http://admin:admin@localhost:8080/job/AI-Product-Insights/buildWithParameters' \
  -d 'ACTION=Build+%26+Push+%26+Deploy' \
  -d 'IMAGE_TAG=v1.0.0'
```

### Docker

```bash
# List built images
docker images | grep saifdine23

# Test push manually
docker push saifdine23/scraper-service:latest

# View image layers
docker history saifdine23/scraper-service:latest
```

### Kubernetes

```bash
# View deployments
kubectl get deployments -n ai-product-insights

# View pods
kubectl get pods -n ai-product-insights

# Check logs
kubectl logs -f deployment/scraper-service -n ai-product-insights
```

---

## 🐛 Troubleshooting

### Jenkins doesn't start

```bash
# Check logs
docker-compose -f ci-cd/docker-compose.jenkins.yml logs jenkins

# Port 8080 in use?
lsof -i :8080
sudo kill -9 <PID>

# Restart
docker-compose -f ci-cd/docker-compose.jenkins.yml restart jenkins
```

### Docker socket error

```bash
# Check socket
ls -la /var/run/docker.sock

# Restart Docker
sudo systemctl restart docker

# Restart Jenkins
docker-compose -f ci-cd/docker-compose.jenkins.yml restart jenkins
```

### Build fails on push

```bash
# Verify credentials
docker login -u saifdine23

# Test push manually
docker push saifdine23/scraper-service:latest

# Check Jenkins credentials
# Manage Jenkins > Manage Credentials > dockerhub-credentials
```

### Images not found

```bash
# Verify images exist
docker images | grep saifdine23

# Build manually
cd backend/scraper-service
docker build -t saifdine23/scraper-service:latest .
docker push saifdine23/scraper-service:latest
```

---

## 🔐 Security

### Credentials Storage

- ✅ DockerHub credentials encrypted
- ✅ GitHub tokens stored securely
- ✅ `.gitignore` prevents leaks
- ✅ CSRF protection enabled
- ✅ Jenkins runs with limited privileges

### Image Security

- ✅ Trivy scans all images (HIGH, CRITICAL)
- ✅ Non-root containers (where possible)
- ✅ Read-only filesystems
- ✅ Resource limits defined
- ✅ Network policies active

---

## 📚 More Info

Full documentation in: `ci-cd/JENKINS-SETUP.md`

Topics covered:
- Detailed installation
- Plugin configuration
- Advanced usage
- GitHub webhooks
- Slack integration
- Monitoring setup
- Backup & restore
- Multi-environment deployments

---

## ✨ Features

✅ **Build Automation**
- Git trigger on push
- Parallel builds (4 services)
- Color-coded output

✅ **Security First**
- Trivy vulnerability scanning
- Docker socket secured
- Credentials encrypted
- CSRF protection

✅ **Enterprise Ready**
- Persistent storage
- Health checks
- Structured logging
- Error handling

✅ **Developer Friendly**
- Custom parameters
- Easy troubleshooting
- Automation scripts
- Clear documentation

---

## 📊 Architecture

```
┌─────────────────────────────────────┐
│  GitHub / Git Repository            │
└────────────────┬────────────────────┘
                 │ Webhook / Manual Trigger
                 ▼
┌─────────────────────────────────────┐
│  Jenkins (http://localhost:8080)    │
│  ├─ Checkout                        │
│  ├─ Build 4 images (parallel)       │
│  ├─ Scan with Trivy                 │
│  ├─ Push to DockerHub               │
│  └─ Deploy to K8s (optional)        │
└────────────────┬────────────────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌─────────┐ ┌──────────┐ ┌──────────┐
│Docker   │ │DockerHub │ │Kubernetes│
│Images   │ │Registry  │ │Cluster   │
└─────────┘ └──────────┘ └──────────┘
```

---

## 🎉 Next Steps

**Today:**
1. ✅ Start Jenkins
2. ✅ Configure credentials
3. ✅ Create pipeline job
4. ✅ Test first build

**This Week:**
1. Setup GitHub webhooks (auto-trigger)
2. Test multi-environment deployment
3. Configure Slack notifications
4. Backup Jenkins configuration

**This Month:**
1. Add unit tests to pipeline
2. Setup ArgoCD for GitOps
3. Configure monitoring (Prometheus/Grafana)
4. Implement rollback strategy

---

## 📞 Support

1. Check logs: `docker-compose logs -f jenkins`
2. Read: `ci-cd/JENKINS-SETUP.md`
3. Review: Troubleshooting section
4. Restart: `docker-compose restart jenkins`

---

**Status:** ✅ Production Ready  
**Version:** 1.0.0  
**Last Updated:** February 2026
