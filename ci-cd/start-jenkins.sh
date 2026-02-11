#!/bin/bash

# ============================================================================
# START JENKINS WITH DOCKER COMPOSE
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "${BLUE}DÉMARRAGE JENKINS${NC}"
echo "${BLUE}════════════════════════════════════════════════════════${NC}"

# ============================================================================
# VÉRIFICATIONS PRÉALABLES
# ============================================================================

echo ""
echo "${YELLOW}Vérification des prérequis...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "${RED}✗ Docker n'est pas installé${NC}"
    exit 1
fi
echo "${GREEN}✓ Docker installé${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "${RED}✗ Docker Compose n'est pas installé${NC}"
    exit 1
fi
echo "${GREEN}✓ Docker Compose installé${NC}"

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo "${RED}✗ Docker daemon n'est pas en cours d'exécution${NC}"
    exit 1
fi
echo "${GREEN}✓ Docker daemon en cours d'exécution${NC}"

# ============================================================================
# CONFIGURATION
# ============================================================================

cd "$(dirname "$0")"

echo ""
echo "${YELLOW}Configuration Jenkins...${NC}"

# Create required directories
mkdir -p init.groovy.d
echo "${GREEN}✓ Répertoires créés${NC}"

# ============================================================================
# DÉMARRAGE JENKINS
# ============================================================================

echo ""
echo "${YELLOW}Démarrage de Jenkins...${NC}"

# Forcer le builder legacy (évite certains soucis réseau/IPv6 avec BuildKit)
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

# Stop existing containers if any
docker compose -f docker-compose.jenkins.yml down 2>/dev/null || true

# Build and start
docker compose -f docker-compose.jenkins.yml up -d

echo "${GREEN}✓ Jenkins démarré${NC}"

# ============================================================================
# ATTENDRE QUE JENKINS SOIT PRÊT
# ============================================================================

echo ""
echo "${YELLOW}Attente du démarrage de Jenkins (cela peut prendre 60 secondes)...${NC}"

max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s -f -o /dev/null http://localhost:8080/; then
        echo "${GREEN}✓ Jenkins est prêt!${NC}"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $((attempt % 10)) -eq 0 ]; then
        echo "  ${YELLOW}En attente... ($attempt/$max_attempts)${NC}"
    fi
    sleep 1
done

if [ $attempt -eq $max_attempts ]; then
    echo "${RED}✗ Jenkins n'a pas démarré à temps${NC}"
    echo ""
    echo "Vérifiez les logs:"
    echo "  docker compose -f docker-compose.jenkins.yml logs jenkins"
    exit 1
fi

# ============================================================================
# AFFICHER LES INFORMATIONS
# ============================================================================

echo ""
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "${GREEN}✓ JENKINS DÉMARRÉ AVEC SUCCÈS!${NC}"
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "${YELLOW}INFORMATIONS D'ACCÈS:${NC}"
echo "  URL: http://localhost:8080"
echo "  Utilisateur: admin"
echo "  Mot de passe: admin"
echo ""
echo "${YELLOW}DOCKER SOCKET:${NC}"
echo "  Disponible pour les builds"
echo ""
echo "${YELLOW}OUTILS INSTALLÉS:${NC}"
echo "  ✓ Docker CLI"
echo "  ✓ Trivy (scanning)"
echo "  ✓ kubectl (Kubernetes)"
echo "  ✓ Helm"
echo "  ✓ Kind"
echo ""
echo "${YELLOW}COMMANDES UTILES:${NC}"
echo "  # Voir les logs"
echo "  docker compose -f docker-compose.jenkins.yml logs -f jenkins"
echo ""
echo "  # Arrêter Jenkins"
echo "  docker compose -f docker-compose.jenkins.yml down"
echo ""
echo "  # Supprimer tout (volumes inclus)"
echo "  docker compose -f docker-compose.jenkins.yml down -v"
echo ""
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "${GREEN}Accédez à Jenkins: http://localhost:8080${NC}"
echo ""
