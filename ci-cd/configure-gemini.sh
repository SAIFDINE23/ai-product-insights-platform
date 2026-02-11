#!/bin/bash

# ============================================================================
# Script: Configure Gemini API Key in Jenkins
# ============================================================================
# Ce script ajoute la clé API Gemini comme credential secret dans Jenkins

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Jenkins Gemini API Key Configuration${NC}"
echo -e "${BLUE}=========================================${NC}\n"

# Check Jenkins is running
JENKINS_URL="http://localhost:8080"
echo -e "${YELLOW}Vérification de Jenkins...${NC}"

if ! curl -s "${JENKINS_URL}/" > /dev/null 2>&1; then
    echo -e "${RED}❌ Jenkins n'est pas accessible sur ${JENKINS_URL}${NC}"
    echo -e "Assurez-vous que Jenkins est en cours d'exécution."
    exit 1
fi
echo -e "${GREEN}✅ Jenkins est accessible${NC}\n"

# Check Jenkins CLI
echo -e "${YELLOW}Vérification de Jenkins CLI...${NC}"
JENKINS_CLI_JAR="jenkins-cli.jar"

if [ ! -f "$JENKINS_CLI_JAR" ]; then
    echo -e "${YELLOW}Téléchargement de jenkins-cli.jar...${NC}"
    curl -s "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o "$JENKINS_CLI_JAR"
    if [ -f "$JENKINS_CLI_JAR" ]; then
        echo -e "${GREEN}✅ jenkins-cli.jar téléchargé${NC}"
    else
        echo -e "${RED}❌ Impossible de télécharger jenkins-cli.jar${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ jenkins-cli.jar présent${NC}"
fi

echo ""

# Prompt for Gemini API Key
echo -e "${YELLOW}🔑 Configuration de la clé API Gemini${NC}"
echo -e "Obtenez votre clé ici: ${BLUE}https://aistudio.google.com/app/apikeys${NC}\n"

read -sp "Entrez votre clé API Gemini (entrée cachée): " GEMINI_API_KEY
echo ""

# Validate API key format
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ La clé API ne peut pas être vide${NC}"
    exit 1
fi

if [[ ! "$GEMINI_API_KEY" =~ ^AIza[A-Za-z0-9_-]{35,}$ ]]; then
    echo -e "${YELLOW}⚠️  Attention: Votre clé ne correspond pas au format attendu (AIza...){NC}"
    read -p "Continuer quand même? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        exit 1
    fi
fi

echo ""

# Create Groovy script for Jenkins
echo -e "${YELLOW}Création de la credential Jenkins...${NC}"

cat > /tmp/create_gemini_credential.groovy << 'EOF'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret

String credentialId = "gemini-api-key"
String apiKey = System.getenv("GEMINI_API_KEY")

// Remove existing credential if it exists
CredentialsProvider.lookupStores(Jenkins.instance).each { store ->
    store.getCredentials(Domain.global()).each { credential ->
        if (credential.id == credentialId) {
            store.updateCredentials(Domain.global(), credential, null)
            println("✓ Credential ancien supprimé")
        }
    }
}

// Create new secret text credential
def credential = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    credentialId,
    "Google Gemini API Key",
    Secret.fromString(apiKey)
)

// Store the credential
def store = Jenkins.instance.getExtensionList(
    'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
)[0].getStore()
store.addCredentials(Domain.global(), credential)

Jenkins.instance.save()
println("✓ Credential Gemini créée avec succès!")
EOF

# Execute Groovy script via Jenkins CLI
export GEMINI_API_KEY="$GEMINI_API_KEY"

java -jar "$JENKINS_CLI_JAR" \
    -s "$JENKINS_URL" \
    groovy = < /tmp/create_gemini_credential.groovy

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Credential Gemini configurée avec succès!${NC}\n"
else
    echo -e "${RED}❌ Erreur lors de la configuration de la credential${NC}"
    exit 1
fi

# Cleanup
rm -f /tmp/create_gemini_credential.groovy

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ Configuration terminée!${NC}"
echo -e "${BLUE}=========================================${NC}\n"

echo -e "La credential ${YELLOW}'gemini-api-key'${NC} est maintenant disponible dans Jenkins."
echo -e "\nUtilisez-la dans le Jenkinsfile avec:"
echo -e "  ${BLUE}withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')])${NC}"

echo -e "\nProchaines étapes:"
echo -e "  1. ${YELLOW}Modifiez le Jenkinsfile${NC} pour utiliser la credential"
echo -e "  2. ${YELLOW}Committez les changements${NC}"
echo -e "  3. ${YELLOW}Lancez le pipeline${NC} depuis Jenkins"

echo ""
