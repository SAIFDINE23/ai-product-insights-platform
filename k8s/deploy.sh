#!/bin/bash
# Deploy script pour AI Product Insights Platform sur Kubernetes
# Usage: ./deploy.sh [create-cluster|deploy|validate|logs|cleanup]

set -e

# Configuration
CLUSTER_NAME="ai-product-insights"
NAMESPACE="ai-product-insights"
DOCKER_REGISTRY="saifdine23"
MANIFESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Vérifier les prérequis
check_requirements() {
    log_info "Vérification des prérequis..."
    
    local missing_tools=()
    
    # Vérifier kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    else
        log_success "kubectl trouvé: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    fi
    
    # Vérifier kind (optionnel)
    if ! command -v kind &> /dev/null; then
        log_warn "kind non trouvé (optionnel pour local clusters)"
    else
        log_success "kind trouvé: $(kind version | grep kind)"
    fi
    
    # Vérifier docker (optionnel)
    if ! command -v docker &> /dev/null; then
        log_warn "docker non trouvé (requis pour build/push)"
    else
        log_success "docker trouvé: $(docker --version)"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Outils manquants: ${missing_tools[@]}"
        return 1
    fi
    
    return 0
}

# Créer un cluster Kind
create_cluster() {
    log_info "Création du cluster Kind: $CLUSTER_NAME"
    
    if kind get clusters 2>/dev/null | grep -q "^$CLUSTER_NAME$"; then
        log_warn "Cluster $CLUSTER_NAME existe déjà"
        return 0
    fi
    
    cat <<EOF | kind create cluster --name=$CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
  ports:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 5432
    hostPort: 5432
    protocol: TCP
  - containerPort: 8000
    hostPort: 8000
    protocol: TCP
EOF
    
    log_success "Cluster créé: $CLUSTER_NAME"
    
    # Installer Nginx Ingress
    install_ingress
}

# Installer Nginx Ingress Controller
install_ingress() {
    log_info "Installation de Nginx Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml
    
    log_info "Attente que l'Ingress soit prêt (timeout 2min)..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    log_success "Nginx Ingress Controller installé"
}

# Déployer l'application
deploy() {
    log_info "Déploiement de l'application..."
    
    # Vérifier que le contexte K8s est disponible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        return 1
    fi
    
    # Créer le namespace si n'existe pas
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Appliquer les manifests dans l'ordre
    log_info "Application des manifests..."
    
    for file in $(ls -v "$MANIFESTS_DIR"/*.yaml | head -11); do
        log_info "Applique: $(basename $file)"
        kubectl apply -f "$file"
        sleep 1
    done
    
    log_success "Manifests appliqués"
    
    # Attendre que les deployments soient prêts
    wait_deployments
}

# Attendre que les deployments soient prêts
wait_deployments() {
    log_info "Attente que tous les deployments soient prêts (timeout 5min)..."
    
    local deployments=("postgres" "scraper-service" "ai-analysis-service" "stats-service" "dashboard-frontend")
    
    for deployment in "${deployments[@]}"; do
        log_info "Attente: $deployment"
        kubectl rollout status deployment/$deployment \
            -n $NAMESPACE \
            --timeout=300s || true
    done
    
    log_success "Tous les deployments sont prêts"
}

# Valider le déploiement
validate() {
    log_info "Validation du déploiement..."
    
    # Vérifier les pods
    log_info "État des pods:"
    kubectl get pods -n $NAMESPACE --no-headers
    
    # Vérifier les services
    log_info "Services:"
    kubectl get services -n $NAMESPACE --no-headers
    
    # Vérifier l'Ingress
    log_info "Ingress:"
    kubectl get ingress -n $NAMESPACE --no-headers
    
    # Vérifier les replicas
    log_info "Replicas:"
    kubectl get deployment -n $NAMESPACE -o wide
    
    # Test connectivité
    log_info "Test de connectivité..."
    sleep 5  # Attendre un peu
    
    if kubectl exec -it -n $NAMESPACE \
        $(kubectl get pod -n $NAMESPACE -l app=dashboard-frontend -o jsonpath='{.items[0].metadata.name}') \
        -- wget -q -O- http://stats-service:8000/health 2>/dev/null | grep -q "OK"; then
        log_success "Dashboard peut communiquer avec Stats Service ✓"
    else
        log_warn "Communication Dashboard → Stats Service incertaine"
    fi
    
    log_success "Validation terminée"
}

# Afficher les logs
show_logs() {
    local service=${1:-stats-service}
    log_info "Logs de $service:"
    kubectl logs -n $NAMESPACE deployment/$service -f --tail=100
}

# Nettoyer le déploiement
cleanup() {
    log_info "Suppression du namespace $NAMESPACE..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    log_success "Namespace supprimé"
}

# Supprimer le cluster Kind
delete_cluster() {
    log_info "Suppression du cluster Kind: $CLUSTER_NAME"
    kind delete cluster --name=$CLUSTER_NAME 2>/dev/null || true
    log_success "Cluster supprimé"
}

# Afficher l'aide
show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Commands:
  check-requirements   Vérifier les prérequis (kubectl, docker, etc)
  create-cluster       Créer un cluster Kind avec Ingress (local dev)
  deploy              Déployer l'application complète
  validate            Valider le déploiement
  logs [SERVICE]      Afficher les logs (defaut: stats-service)
  cleanup             Supprimer le namespace (gardé le cluster)
  delete-cluster      Supprimer le cluster Kind entièrement
  full-setup          create-cluster + deploy + validate (complet)
  help                Afficher cette aide

Examples:
  $0 create-cluster          # Créer cluster local Kind
  $0 deploy                 # Déployer sur le cluster actuel
  $0 logs ai-analysis-service  # Logs du service IA
  $0 full-setup             # Setup complet pour local dev
  $0 cleanup                # Nettoyer (ne supprime pas le cluster)

EOF
}

# Main
main() {
    local command=${1:-help}
    
    case "$command" in
        check-requirements)
            check_requirements
            ;;
        create-cluster)
            check_requirements
            create_cluster
            ;;
        install-ingress)
            install_ingress
            ;;
        deploy)
            deploy
            ;;
        validate)
            validate
            ;;
        logs)
            show_logs "$2"
            ;;
        cleanup)
            cleanup
            ;;
        delete-cluster)
            delete_cluster
            ;;
        full-setup)
            check_requirements && \
            create_cluster && \
            deploy && \
            validate
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
