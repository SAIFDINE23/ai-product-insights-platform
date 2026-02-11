# ADVANCED-USAGE.md - Cas d'usage avancés Kubernetes

## Table des matières

1. [Kustomize pour multi-environnements](#kustomize-pour-multi-environnements)
2. [Helm Charts](#helm-charts)
3. [Overlays (dev/staging/prod)](#overlays-devstaging-prod)
4. [GitOps avec ArgoCD](#gitops-avec-argocd)
5. [Advanced Networking](#advanced-networking)
6. [Security Hardening](#security-hardening)
7. [Performance Tuning](#performance-tuning)

---

## Kustomize pour multi-environnements

### Structure recommandée

```
k8s/
├── base/                    # Ressources de base (communes)
│   ├── kustomization.yaml
│   ├── deployments.yaml
│   ├── services.yaml
│   └── ...
├── overlays/               # Variantes par environnement
│   ├── development/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
└── README.md
```

### Utilisation

```bash
# Développement
kubectl apply -k k8s/overlays/development/

# Staging
kubectl apply -k k8s/overlays/staging/

# Production
kubectl apply -k k8s/overlays/production/

# Juste visualiser sans appliquer
kubectl apply -k k8s/overlays/production/ --dry-run=client
```

### Exemple: Overlay production

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base/

# Replicas augmentés pour production
replicas:
  - name: stats-service
    count: 3
  - name: dashboard-frontend
    count: 3

# Patches pour production
patches:
  - target:
      kind: Deployment
      name: postgres
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "2Gi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "1Gi"

# Images pour production
images:
  - name: saifdine23/stats-service
    newTag: "v1.0.0"  # Version spécifique, pas latest!

# ConfigMaps pour production
configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - LOG_LEVEL=WARN
      - ENVIRONMENT=production

# Secrets pour production (attention: à utiliser avec Sealed Secrets!)
secretGenerator:
  - name: postgres-credentials
    behavior: merge
    literals:
      - username=prod_user
      - password=SECURE_PASSWORD_HERE  # À remplacer!
```

---

## Helm Charts

### Créer un Helm Chart

```bash
# Scaffolder un nouveau chart
helm create ai-product-insights

# Structure du chart
ai-product-insights/
├── Chart.yaml              # Metadata du chart
├── values.yaml              # Valeurs par défaut
├── values-dev.yaml          # Overrides dev
├── values-prod.yaml         # Overrides prod
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── _helpers.tpl
└── README.md
```

### Utiliser le Helm Chart

```bash
# Installer avec les valeurs par défaut
helm install ai-product-insights ./ai-product-insights

# Installer avec des overrides dev
helm install ai-product-insights ./ai-product-insights \
  -f ai-product-insights/values-dev.yaml \
  -n ai-product-insights-dev \
  --create-namespace

# Installer en production avec des valeurs custom
helm install ai-product-insights ./ai-product-insights \
  -f ai-product-insights/values-prod.yaml \
  --set postgres.replication.enabled=true \
  --set monitoring.enabled=true \
  -n ai-product-insights-prod \
  --create-namespace

# Upgrade une release existante
helm upgrade ai-product-insights ./ai-product-insights \
  -f ai-product-insights/values-prod.yaml

# Rollback si problème
helm rollback ai-product-insights 1  # Revenir à la version précédente

# Vérifier les releases
helm list
helm history ai-product-insights
```

### Exemple: values.yaml

```yaml
# Default values for ai-product-insights
replicaCount: 1

image:
  repository: saifdine23
  tag: latest
  pullPolicy: IfNotPresent

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: localhost
      paths:
        - path: /
          pathType: Prefix

postgres:
  enabled: true
  image:
    tag: 16-alpine
  storage:
    size: 10Gi
  credentials:
    username: app_user
    password: app_password

services:
  scraper:
    replicas: 1
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
  aiAnalysis:
    replicas: 1
    resources:
      requests:
        memory: 256Mi
        cpu: 200m
  stats:
    replicas: 1
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
  frontend:
    replicas: 2
    resources:
      requests:
        memory: 64Mi
        cpu: 50m

hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70

monitoring:
  enabled: false
  prometheus: false
  grafana: false

networkPolicies:
  enabled: true
  denyAll: true
```

---

## Overlays (dev/staging/prod)

### Structure avec overlays

```bash
# Créer la structure
mkdir -p k8s/base k8s/overlays/{dev,staging,prod}

# Déplacer les manifests vers base/
mv k8s/0*.yaml k8s/base/
mv k8s/0*.yaml k8s/base/

# Créer kustomization.yaml pour chaque overlay
```

### Overlay Development

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

namePrefix: dev-
namespace: ai-product-insights-dev

replicas:
  - name: postgres
    count: 1
  - name: scraper-service
    count: 1
  - name: stats-service
    count: 1
  - name: dashboard-frontend
    count: 1  # Moins de replicas en dev

configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - LOG_LEVEL=DEBUG

patchesJson6902:
  - target:
      kind: HorizontalPodAutoscaler
      name: stats-service-hpa
    patch: |-
      - op: replace
        path: /spec/maxReplicas
        value: 2  # Max 2 en dev
```

### Overlay Production

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

namespace: ai-product-insights-prod

# Replicas maximales
replicas:
  - name: postgres
    count: 1  # Or: utiliser StatefulSet + replication
  - name: scraper-service
    count: 2
  - name: stats-service
    count: 2
  - name: dashboard-frontend
    count: 3

# Images en production: versions explicites, pas latest!
images:
  - name: saifdine23/scraper-service
    newTag: "v1.0.0"
  - name: saifdine23/ai-analysis-service
    newTag: "v1.0.0"
  - name: saifdine23/stats-service
    newTag: "v1.0.0"
  - name: saifdine23/dashboard-frontend
    newTag: "v1.0.0"
  - name: postgres
    newTag: "16-alpine"

# Resources limits plus hautes
patchesJson6902:
  - target:
      kind: Deployment
      name: stats-service
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "512Mi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: "500m"

# Monitoring activé en production
configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - LOG_LEVEL=INFO
      - ENVIRONMENT=production

# Affinity stricte
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/spec/affinity
        value:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - stats-service
                topologyKey: kubernetes.io/hostname
```

### Déployer les overlays

```bash
# Développement
kustomize build overlays/dev | kubectl apply -f -

# Ou:
kubectl apply -k overlays/dev/

# Staging
kubectl apply -k overlays/staging/

# Production
kubectl apply -k overlays/prod/

# Visualiser sans appliquer
kubectl apply -k overlays/prod/ --dry-run=client -o yaml
```

---

## GitOps avec ArgoCD

### Installer ArgoCD

```bash
# Installer ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Accéder à ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# URL: https://localhost:8080
# Récupérer le password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Créer une Application ArgoCD

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ai-product-insights
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
  
  syncPolicy:
    automated:
      prune: true      # Supprimer les ressources non déclarées
      selfHeal: true   # Synchroniser auto si dérive
    syncOptions:
      - CreateNamespace=true

# Appliquer
kubectl apply -f argocd-application.yaml
```

### Avantages de GitOps

- **Source of Truth**: Git est la source unique de vérité
- **Audit Trail**: Chaque change est tracé dans Git
- **Easy Rollback**: Revert un commit = rollback du déploiement
- **Declarative**: Kubernetes désiré état toujours en Git
- **Multi-cluster**: Une fois l'Application créée, ArgoCD synchronise automatiquement

---

## Advanced Networking

### Service Mesh (Istio)

```bash
# Installer Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*/
./bin/istioctl install --set profile=demo -y

# Ajouter labels au namespace pour l'injection sidecar
kubectl label namespace ai-product-insights istio-injection=enabled

# Redéployer
kubectl rollout restart deployment -n ai-product-insights

# Vérifier les sidecars
kubectl get pods -n ai-product-insights -o jsonpath='{range .items[*]}{.metadata.name} {.spec.containers[*].name}{"\n"}{end}'
```

### VirtualService + DestinationRule (avec Istio)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: stats-service
  namespace: ai-product-insights
spec:
  hosts:
    - stats-service
  http:
    - match:
        - uri:
            prefix: /health
      route:
        - destination:
            host: stats-service
            port:
              number: 8000
    - route:
        - destination:
            host: stats-service
            port:
              number: 8000
          weight: 80
        - destination:
            host: stats-service
            port:
              number: 8000
          weight: 20  # Canary deployment: 20% vers nouvelle version
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: stats-service
  namespace: ai-product-insights
spec:
  host: stats-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: ROUND_ROBIN
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

---

## Security Hardening

### Sealed Secrets (pour secrets en Git)

```bash
# Installer Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml -n kube-system

# Créer un secret scellé
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o json | \
  kubeseal -f - > mysealedsecret.json

# Appliquer le secret scellé
kubectl apply -f mysealedsecret.json
```

### Pod Security Policy (K8s < 1.25)

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: true
```

### Pod Security Standards (K8s >= 1.25)

```bash
# Étiqueter le namespace avec le niveau de sécurité
kubectl label namespace ai-product-insights pod-security.kubernetes.io/enforce=restricted

# Vérifier
kubectl get ns ai-product-insights -o yaml
```

### Network Security

```bash
# Exemple: Deny all + Allow spécifique
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ai-product-insights
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: ai-product-insights
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
EOF
```

---

## Performance Tuning

### Database Performance

```bash
# Index et optimisations
kubectl exec -it -n ai-product-insights \
  $(kubectl get pod -n ai-product-insights -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U app_user -d product_insights -c "
  CREATE INDEX IF NOT EXISTS idx_reviews_sentiment ON reviews_analysis(sentiment);
  VACUUM ANALYZE;
"

# Connection pooling (pgBouncer)
# À ajouter: pgBouncer en tant que service distinct
```

### Frontend Caching

```yaml
# Ajouter à Ingress pour le caching
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cache-ingress
  annotations:
    nginx.ingress.kubernetes.io/proxy-cache: "on"
    nginx.ingress.kubernetes.io/proxy-cache-valid: "200 60m"
    nginx.ingress.kubernetes.io/proxy-cache-key: "$scheme$request_method$host$request_uri"
spec:
  # ...
```

### Resource Requests/Limits Optimization

```bash
# Metrics Server doit être installé
kubectl get deployment metrics-server -n kube-system

# Voir les metrics réels
kubectl top pods -n ai-product-insights
kubectl top nodes

# Ajuster les requests/limits selon les metrics observés
# Ne pas mettre limits trop bas (OOMKilled)
# Ne pas mettre requests trop hauts (gaspillage de ressources)
```

### Horizontal Pod Autoscaler Tuning

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stats-service-hpa-advanced
  namespace: ai-product-insights
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stats-service
  minReplicas: 1
  maxReplicas: 10
  metrics:
    # Basée sur CPU
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    # Basée sur mémoire
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
    # Basée sur metrics custom (ex: requêtes/sec)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: 1000
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 600  # Attendre 10 min avant de descendre
      policies:
        - type: Percent
          value: 25  # Descendre de 25% max
          periodSeconds: 60
        - type: Pods
          value: 1
          periodSeconds: 60
      selectPolicy: Min  # Prendre la politique moins agressive
    scaleUp:
      stabilizationWindowSeconds: 30  # Scale-up rapide
      policies:
        - type: Percent
          value: 100  # Doubler si besoin
          periodSeconds: 15
        - type: Pods
          value: 2
          periodSeconds: 15
      selectPolicy: Max  # Prendre la politique la plus agressive
```

---

## Troubleshooting Avancé

```bash
# Debug détaillé
kubectl get events -n ai-product-insights --sort-by='.lastTimestamp'

# Tracer les appels réseau
kubectl run -it --rm --image=nicolaka/netshoot --restart=Never debug -- sh
# À l'intérieur: tcpdump, traceroute, curl avec verbose, etc.

# Entrer dans un container
kubectl exec -it <pod> -c <container> -- /bin/sh

# Port forward pour debugging local
kubectl port-forward svc/stats-service 8000:8000 -n ai-product-insights

# Logs avec recherche
kubectl logs -n ai-product-insights -l app=stats-service | grep -i error

# JSON query avancée
kubectl get pods -n ai-product-insights -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
```

---

**Dernier update**: Février 2026  
**Kubernetes**: 1.20+  
**Niveau**: Avancé
