# CICD-INTEGRATION.md - Intégration Kubernetes avec CI/CD

## Table des matières

1. [GitHub Actions pour Kubernetes](#github-actions-pour-kubernetes)
2. [ArgoCD GitOps Workflow](#argocd-gitops-workflow)
3. [Helm + CI/CD](#helm--cicd)
4. [Kustomize + CI/CD](#kustomize--cicd)
5. [Security Scanning dans le Pipeline](#security-scanning-dans-le-pipeline)

---

## GitHub Actions pour Kubernetes

### Workflow: Build → Test → Push → Deploy

```yaml
# .github/workflows/k8s-deploy.yml
name: Kubernetes Deployment

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

env:
  REGISTRY: docker.io
  IMAGE_NAME: saifdine23

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v3
      
      # Build et push des images
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      
      - name: Build and push stats-service
        uses: docker/build-push-action@v4
        with:
          context: ./backend/stats-service
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/stats-service:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/stats-service:${{ github.sha }}
      
      - name: Build and push ai-analysis-service
        uses: docker/build-push-action@v4
        with:
          context: ./backend/ai-analysis-service
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/ai-analysis-service:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/ai-analysis-service:${{ github.sha }}
      
      # ... autres services

  security-scan:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/stats-service:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  deploy-dev:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubectl
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.KUBE_CONFIG_DEV }}" | base64 -d > $HOME/.kube/config
      
      - name: Update images with kustomize
        run: |
          cd k8s/overlays/dev
          kustomize edit set image saifdine23/stats-service=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/stats-service:${{ github.sha }}
          kustomize edit set image saifdine23/ai-analysis-service=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/ai-analysis-service:${{ github.sha }}
      
      - name: Deploy to DEV cluster
        run: kubectl apply -k k8s/overlays/dev/
      
      - name: Wait for rollout
        run: kubectl rollout status deployment/stats-service -n ai-product-insights-dev --timeout=5m

  deploy-prod:
    needs: [build-and-push, security-scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # Nécessite approval
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubectl
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.KUBE_CONFIG_PROD }}" | base64 -d > $HOME/.kube/config
      
      - name: Update images with kustomize
        run: |
          cd k8s/overlays/prod
          kustomize edit set image saifdine23/stats-service=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/stats-service:${{ github.sha }}
          kustomize edit set image saifdine23/ai-analysis-service=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/ai-analysis-service:${{ github.sha }}
      
      - name: Deploy to PROD cluster
        run: kubectl apply -k k8s/overlays/prod/
      
      - name: Verify deployment
        run: |
          kubectl rollout status deployment/stats-service -n ai-product-insights-prod --timeout=5m
          kubectl get pods -n ai-product-insights-prod
      
      - name: Slack notification
        if: always()
        uses: slackapi/slack-github-action@v1.24.0
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "Production deployment: ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Kubernetes Deployment Status*\n*Status*: ${{ job.status }}\n*Commit*: ${{ github.sha }}\n*Author*: ${{ github.actor }}"
                  }
                }
              ]
            }
```

### Commandes dans le pipeline

```bash
# Vérifier les kubeconfigs
kubectl cluster-info

# Valider les manifests
kubectl apply -f k8s/ --dry-run=client -o yaml

# Appliquer progressivement
kubectl apply -f k8s/ --record --validate=true

# Vérifier le rollout
kubectl rollout status deployment/stats-service -n ai-product-insights --timeout=5m

# Smoke tests
curl -f http://localhost/health || exit 1
```

---

## ArgoCD GitOps Workflow

### Workflow GitOps avec ArgoCD

```
Git Repository (main branch)
    │
    ├─ k8s/
    │  ├─ overlays/
    │  │  └─ prod/
    │  │     └─ kustomization.yaml
    │  └─ base/
    │     └─ *.yaml
    │
    └─ argocd-app.yaml
         │
         ▼
    ArgoCD (cluster)
         │
         ├─ Watch Git for changes
         ├─ Detect differences (drift detection)
         └─ Auto-apply or wait for approval
         │
         ▼
    Kubernetes Cluster
         │
         ▼
    Application Running
```

### Configuration ArgoCD

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ai-product-insights-prod
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/SAIFDINE23/ai-product-insights-platform
    targetRevision: main
    path: k8s/overlays/prod
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ai-product-insights-prod
  
  # Synchronization policy
  syncPolicy:
    automated:
      prune: true      # Supprimer les ressources non déclarées
      selfHeal: true   # Resynchroniser si dérive
      
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
      
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

---
# AppProject pour contrôler les permissions
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ai-product-insights
  namespace: argocd
spec:
  description: AI Product Insights Platform
  
  # Repos source autorisés
  sourceRepos:
    - 'https://github.com/SAIFDINE23/*'
  
  # Clusters destination autorisés
  destinations:
    - namespace: 'ai-product-insights-prod'
      server: https://kubernetes.default.svc
    - namespace: 'ai-product-insights-staging'
      server: https://kubernetes.default.svc
    - namespace: 'ai-product-insights-dev'
      server: https://kubernetes.default.svc
  
  # Policies d'accès RBAC
  roles:
    - name: admin
      policies:
        - p, proj:ai-product-insights:admin, applications, *, ai-product-insights-*/*, allow
    
    - name: read-only
      policies:
        - p, proj:ai-product-insights:read-only, applications, get, ai-product-insights-*/*, allow
```

### Deployer avec ArgoCD

```bash
# Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Accéder à l'UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Password par défaut: admin / <secret argocd-initial-admin-secret>

# Créer l'application
kubectl apply -f argocd-application.yaml

# Trigger une synchronisation manuelle
argocd app sync ai-product-insights-prod --prune

# Voir le statut
argocd app get ai-product-insights-prod

# Rollback à la revision précédente
argocd app rollback ai-product-insights-prod
```

### Avantages GitOps

✅ **Single Source of Truth**: Git est la source unique  
✅ **Audit Trail**: Chaque change est tracé  
✅ **Rollback facile**: `git revert` = déploiement précédent  
✅ **Pull-based**: Cluster pull les changements (plus sûr)  
✅ **Drift detection**: Automatiquement détecte les dérives  

---

## Helm + CI/CD

### Build et push Helm Charts

```yaml
# .github/workflows/helm-publish.yml
name: Publish Helm Chart

on:
  push:
    branches:
      - main
    paths:
      - 'helm/**'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: '3.12.0'
      
      - name: Package Helm Chart
        run: |
          helm package ./helm/ai-product-insights \
            --destination ./helm-releases
      
      - name: Push to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./helm-releases
      
      - name: Create Chart index
        run: helm repo index ./helm-releases
      
      - name: Push to Helm repository
        run: |
          helm repo add ai-insights https://github.com/SAIFDINE23/ai-product-insights
          helm repo update
```

### Utiliser le Helm Chart en production

```bash
# Ajouter le repo
helm repo add ai-insights https://github.com/SAIFDINE23/ai-product-insights
helm repo update

# Installer avec overrides production
helm install ai-product-insights ai-insights/ai-product-insights \
  --namespace ai-product-insights-prod \
  --create-namespace \
  -f values-prod.yaml \
  --values values-prod.yaml

# Upgrade vers une nouvelle version
helm upgrade ai-product-insights ai-insights/ai-product-insights \
  -f values-prod.yaml

# Rollback
helm rollback ai-product-insights
```

---

## Kustomize + CI/CD

### Structure avec overlays pour CI/CD

```
k8s/
├── base/                    # Ressources communes
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
└── patches/                 # Patches réutilisables
    ├── image-dev-patch.yaml
    └── image-prod-patch.yaml
```

### GitHub Actions avec Kustomize

```yaml
# .github/workflows/kustomize-deploy.yml
name: Kustomize Deploy

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - branch: develop
            overlay: dev
          - branch: main
            overlay: prod
    
    if: github.ref == format('refs/heads/{0}', matrix.branch)
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Kustomize
        run: |
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          sudo mv kustomize /usr/local/bin/
      
      - name: Update image tags
        run: |
          cd k8s/overlays/${{ matrix.overlay }}
          kustomize edit set image \
            saifdine23/stats-service=docker.io/saifdine23/stats-service:${{ github.sha }}
      
      - name: Build manifests
        run: kustomize build k8s/overlays/${{ matrix.overlay }} > manifests.yaml
      
      - name: Validate manifests
        run: kubectl apply -f manifests.yaml --dry-run=client --validate=true
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Configure kubeconfig
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets[format('KUBE_CONFIG_{0}', matrix.overlay)] }}" | base64 -d > $HOME/.kube/config
      
      - name: Deploy
        run: kubectl apply -k k8s/overlays/${{ matrix.overlay }}/
      
      - name: Wait for rollout
        run: kubectl rollout status deployment/stats-service -n ai-product-insights-${{ matrix.overlay }} --timeout=5m
```

---

## Security Scanning dans le Pipeline

### Scanning images avec Trivy

```yaml
# .github/workflows/security-scan.yml
name: Security Scanning

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Fail on high severity
        run: |
          docker run --rm -v $(pwd):/workspace \
            aquasec/trivy:latest fs \
            --exit-code 1 \
            --severity HIGH,CRITICAL \
            /workspace

  kubesec-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Scan Kubernetes manifests with Kubesec
        run: |
          docker run --rm -v $(pwd):/workspace \
            kubesec/kubesec:latest scan k8s/*.yaml \
            | tee kubesec-report.json
      
      - name: Check Kubesec score
        run: |
          SCORE=$(cat kubesec-report.json | jq '.[0].score // 0')
          if (( $(echo "$SCORE < 5" | bc -l) )); then
            echo "Kubesec score too low: $SCORE"
            exit 1
          fi

  policy-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Check Kubernetes security policies with OPA/Conftest
        run: |
          # Installer conftest
          curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz | tar xzf -
          
          # Créer les policies
          mkdir -p policies
          cat > policies/security.rego << 'EOF'
          package main
          
          deny[msg] {
            input.kind == "Deployment"
            not input.spec.template.spec.securityContext.runAsNonRoot
            msg := "Deployment must run as non-root"
          }
          
          deny[msg] {
            input.kind == "Deployment"
            input.spec.template.spec.containers[_].securityContext.privileged == true
            msg := "Containers must not run as privileged"
          }
          EOF
          
          # Tester les manifests
          ./conftest test -p policies k8s/*.yaml
```

---

## Flux CD (Alternative à ArgoCD)

### Configuration Flux

```yaml
# flux-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ai-product-insights
  namespace: flux-system
spec:
  interval: 5m
  path: ./k8s/overlays/prod
  sourceRef:
    kind: GitRepository
    name: ai-product-insights
  prune: true
  wait: true
  retryInterval: 1m
  timeout: 5m

---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: ai-product-insights
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/SAIFDINE23/ai-product-insights-platform
  ref:
    branch: main
  secretRef:
    name: github-credentials  # GitHub token
```

---

## Pre-deployment Validation

```bash
# Valider les manifests Kubernetes
kubectl apply -f k8s/ --dry-run=client --validate=true

# Valider la syntaxe JSON
jq . k8s/*.yaml

# Vérifier les images existent
docker manifest inspect saifdine23/stats-service:latest

# Smoke tests après deployment
curl -f http://localhost/health
curl -f http://localhost/api/stats/sentiment
```

---

## Rollback Strategy

```bash
# Dans le pipeline:
# 1. Déployer la nouvelle version
kubectl apply -k overlays/prod/

# 2. Attendre que les tests passent
kubectl rollout status deployment/stats-service -n ai-product-insights-prod

# 3. Si problème:
kubectl rollout undo deployment/stats-service -n ai-product-insights-prod

# Avec Helm:
helm rollback ai-product-insights

# Avec ArgoCD:
argocd app rollback ai-product-insights-prod

# Avec Flux:
flux suspend kustomization ai-product-insights
git revert <commit-id>
git push
flux resume kustomization ai-product-insights
```

---

**Production-Ready CI/CD pour Kubernetes ✅**
