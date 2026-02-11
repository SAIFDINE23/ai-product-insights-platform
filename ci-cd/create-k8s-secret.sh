#!/bin/bash

# ============================================================================
# Script: Créer Kubernetes Secret pour Gemini API Key
# ============================================================================
# 
# Usage: ./ci-cd/create-k8s-secret.sh
#
# Ce script crée sécurément un secret Kubernetes avec l'API Key Gemini

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Kubernetes Secret Creation - Gemini API Key${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"

# ============================================================================
# VÉRIFICATIONS
# ============================================================================

echo -e "${YELLOW}📋 Vérifications...${NC}\n"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl non trouvé${NC}"
    echo "Installez kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo -e "${GREEN}✅ kubectl disponible${NC}"

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Impossible de se connecter au cluster Kubernetes${NC}"
    echo "Vérifiez votre kubeconfig et votre cluster"
    exit 1
fi
echo -e "${GREEN}✅ Cluster Kubernetes accessible${NC}"

# ============================================================================
# CRÉER NAMESPACE
# ============================================================================

NAMESPACE="ai-product-insights"

echo -e "\n${YELLOW}📦 Création du namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✅ Namespace '$NAMESPACE' existe déjà${NC}"
else
    echo -e "${YELLOW}   Création de '$NAMESPACE'...${NC}"
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}✅ Namespace créé${NC}"
fi

# ============================================================================
# INPUT: API KEY GEMINI
# ============================================================================

echo -e "\n${YELLOW}🔑 Configuration de l'API Key Gemini${NC}"
echo -e "Obtenez votre clé: ${BLUE}https://aistudio.google.com/app/apikeys${NC}\n"

read -sp "Entrez votre API Key Gemini (entrée cachée): " GEMINI_API_KEY
echo ""

if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ L'API Key ne peut pas être vide${NC}"
    exit 1
fi

if [[ ! "$GEMINI_API_KEY" =~ ^AIza ]]; then
    echo -e "${YELLOW}⚠️  Attention: Votre clé ne commence pas par 'AIza'${NC}"
    read -p "Continuer? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ API Key fournie${NC}"

# ============================================================================
# INPUT: DATABASE CREDENTIALS
# ============================================================================

echo -e "\n${YELLOW}🔐 Credentials de la base de données${NC}\n"

read -p "Entrez DB_USER (défaut: app_user): " DB_USER
DB_USER=${DB_USER:-app_user}

read -sp "Entrez DB_PASSWORD (entrée cachée): " DB_PASSWORD
echo ""
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ Le mot de passe DB ne peut pas être vide${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Credentials DB fournis${NC}"

# ============================================================================
# VÉRIFIER SI SECRET EXISTE DÉJÀ
# ============================================================================

echo -e "\n${YELLOW}🔍 Vérification des secrets existants...${NC}\n"

if kubectl get secret ai-analysis-secrets -n "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Le secret 'ai-analysis-secrets' existe déjà${NC}"
    read -p "Voulez-vous le remplacer? (y/n): " replace_secret
    
    if [[ "$replace_secret" == "y" ]]; then
        echo -e "${YELLOW}   Suppression de l'ancien secret...${NC}"
        kubectl delete secret ai-analysis-secrets -n "$NAMESPACE"
        echo -e "${GREEN}✅ Secret supprimé${NC}"
    else
        echo -e "${YELLOW}Opération annulée${NC}"
        exit 0
    fi
fi

# ============================================================================
# CRÉER LE SECRET
# ============================================================================

echo -e "\n${YELLOW}🔐 Création du secret Kubernetes...${NC}\n"

kubectl create secret generic ai-analysis-secrets \
    --from-literal=GEMINI_API_KEY="$GEMINI_API_KEY" \
    --from-literal=DB_USER="$DB_USER" \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    -n "$NAMESPACE" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Secret 'ai-analysis-secrets' créé/mis à jour${NC}"
else
    echo -e "${RED}❌ Erreur lors de la création du secret${NC}"
    exit 1
fi

# ============================================================================
# CRÉER CONFIGMAP
# ============================================================================

echo -e "\n${YELLOW}⚙️  Création du ConfigMap...${NC}\n"

kubectl create configmap ai-analysis-config \
    --from-literal=SERVICE_NAME=ai-analysis-service \
    --from-literal=SERVICE_PORT=8000 \
    --from-literal=LOG_LEVEL=INFO \
    --from-literal=DB_HOST=postgres \
    --from-literal=DB_PORT=5432 \
    --from-literal=DB_NAME=product_insights \
    --from-literal=GEMINI_MODEL=gemini-2.0-flash \
    --from-literal=GEMINI_MAX_RETRIES=3 \
    --from-literal=GEMINI_TIMEOUT=30 \
    -n "$NAMESPACE" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ConfigMap 'ai-analysis-config' créé/mis à jour${NC}"
else
    echo -e "${RED}❌ Erreur lors de la création du ConfigMap${NC}"
    exit 1
fi

# ============================================================================
# VÉRIFICATIONS
# ============================================================================

echo -e "\n${YELLOW}✔️  Vérification des ressources créées...${NC}\n"

echo -e "${BLUE}Secrets dans le namespace:${NC}"
kubectl get secrets -n "$NAMESPACE" --no-headers | grep ai-analysis-secrets

echo -e "\n${BLUE}ConfigMaps dans le namespace:${NC}"
kubectl get configmaps -n "$NAMESPACE" --no-headers | grep ai-analysis-config

# ============================================================================
# RÉSUMÉ
# ============================================================================

echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ CONFIGURATION RÉUSSIE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}\n"

echo -e "${BLUE}Ressources créées:${NC}"
echo "  • Namespace: $NAMESPACE"
echo "  • Secret: ai-analysis-secrets"
echo "    - GEMINI_API_KEY"
echo "    - DB_USER: $DB_USER"
echo "    - DB_PASSWORD: ****"
echo "  • ConfigMap: ai-analysis-config"

echo -e "\n${BLUE}Prochaines étapes:${NC}"
echo "  1. Appliquer le deployment:"
echo -e "     ${YELLOW}kubectl apply -f k8s/ai-analysis-service.yaml${NC}"
echo ""
echo "  2. Vérifier que les pods sont en running:"
echo -e "     ${YELLOW}kubectl get pods -n ai-product-insights${NC}"
echo ""
echo "  3. Voir les logs:"
echo -e "     ${YELLOW}kubectl logs -f deployment/ai-analysis-service -n ai-product-insights${NC}"
echo ""
echo "  4. Tester le service:"
echo -e "     ${YELLOW}kubectl port-forward svc/ai-analysis-service 8000:8000 -n ai-product-insights${NC}"
echo "     Puis: curl http://localhost:8000/health"

echo -e "\n${BLUE}Commandes utiles:${NC}"
echo "  • Voir le secret (valeurs masquées):"
echo -e "    ${YELLOW}kubectl describe secret ai-analysis-secrets -n ai-product-insights${NC}"
echo ""
echo "  • Décoder une valeur (DEBUG ONLY):"
echo -e "    ${YELLOW}kubectl get secret ai-analysis-secrets -n ai-product-insights -o jsonpath='{.data.GEMINI_API_KEY}' | base64 --decode${NC}"
echo ""
echo "  • Supprimer le secret:"
echo -e "    ${YELLOW}kubectl delete secret ai-analysis-secrets -n ai-product-insights${NC}"

echo -e "\n${GREEN}Status: 🟢 Secrets Kubernetes prêts pour le déploiement!${NC}\n"
