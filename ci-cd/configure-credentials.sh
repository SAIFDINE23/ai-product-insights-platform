#!/bin/bash

# ============================================================================
# CONFIGURE JENKINS CREDENTIALS (DockerHub)
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "${BLUE}CONFIGURATION DES CREDENTIALS JENKINS${NC}"
echo "${BLUE}════════════════════════════════════════════════════════${NC}"

# ============================================================================
# INPUTS
# ============================================================================

echo ""
echo "${YELLOW}Veuillez entrer vos informations DockerHub:${NC}"
read -p "DockerHub Username: " DOCKER_USER
read -sp "DockerHub Password/Token: " DOCKER_PASS
echo ""

# Validate
if [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PASS" ]; then
    echo "${RED}✗ Les informations sont requises${NC}"
    exit 1
fi

echo ""
echo "${YELLOW}URL du repo GitHub (optionnel):${NC}"
read -p "GitHub URL (appuyez sur Entrée pour passer): " GITHUB_URL

read -p "GitHub Token (appuyez sur Entrée pour passer): " GITHUB_TOKEN

# ============================================================================
# CREATE JENKINS CREDENTIALS VIA GROOVY
# ============================================================================

JENKINS_HOME="/var/jenkins_home"
CREDENTIALS_DIR="${JENKINS_HOME}/credentials.xml"
SECRETS_DIR="${JENKINS_HOME}/secrets"

echo ""
echo "${YELLOW}Création des credentials Jenkins via Groovy...${NC}"

docker exec jenkins-server bash -c "cat > /tmp/add-credentials.groovy" << 'GROOVY_EOF'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import hudson.util.Secret

def jenkins = Jenkins.getInstance()

// DockerHub Credentials
def store = jenkins.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def domain = Domain.global()

// Create DockerHub credential
def dockerhubCred = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    'dockerhub-credentials',
    'DockerHub Credentials',
    System.getenv('DOCKER_USER'),
    System.getenv('DOCKER_PASS')
)

// Check if already exists
def existing = CredentialsProvider.lookupCredentials(
    UsernamePasswordCredentials.class,
    jenkins,
    null,
    null
)

def exists = existing.any { it.id == 'dockerhub-credentials' }

if (!exists) {
    store.addCredentials(domain, dockerhubCred)
    println("✓ DockerHub credentials added")
} else {
    println("✓ DockerHub credentials already exist")
}

jenkins.save()
GROOVY_EOF

# Exécuter le script Groovy via Jenkins CLI
docker exec -e DOCKER_USER="${DOCKER_USER}" -e DOCKER_PASS="${DOCKER_PASS}" \
    jenkins-server bash -c "curl -sSL http://localhost:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar && \
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin groovy = < /tmp/add-credentials.groovy"

echo "${GREEN}✓ Credentials créés${NC}"

# ============================================================================
# CONFIGURE GIT GLOBAL
# ============================================================================

echo ""
echo "${YELLOW}Configuration Git dans Jenkins...${NC}"

docker exec jenkins-server git config --global user.email "jenkins@localhost" || true
docker exec jenkins-server git config --global user.name "Jenkins CI" || true

echo "${GREEN}✓ Configuration Git complétée${NC}"

# ============================================================================
# AFFICHER LES INSTRUCTIONS
# ============================================================================

echo ""
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo "${GREEN}✓ CREDENTIALS CONFIGURÉS!${NC}"
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "${YELLOW}PROCHAINES ÉTAPES:${NC}"
echo "1. Allez sur http://localhost:8080"
echo "2. Connectez-vous (admin/admin)"
echo "3. Allez sur 'Manage Jenkins' > 'Manage Credentials'"
echo "4. Vérifiez que 'dockerhub-credentials' est présent"
echo ""
echo "${YELLOW}POUR CRÉER UN PIPELINE JOB:${NC}"
echo "1. New Item"
echo "2. Entrez le nom: 'AI-Product-Insights'"
echo "3. Sélectionnez 'Pipeline'"
echo "4. Dans 'Pipeline', sélectionnez 'Pipeline script from SCM'"
echo "5. SCM: Git"
echo "6. Repository URL: https://github.com/<your-repo>"
echo "7. Credentials: (vos GitHub credentials si privé)"
echo "8. Script Path: Jenkinsfile"
echo "9. Save & Build"
echo ""
echo "${BLUE}════════════════════════════════════════════════════════${NC}"
