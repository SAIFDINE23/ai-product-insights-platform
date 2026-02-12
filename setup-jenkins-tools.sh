#!/bin/bash

# ============================================================================
# JENKINS SETUP SCRIPT
# Install and configure all tools needed for the pipeline
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Jenkins Environment Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

# ============================================================================
# 1. INSTALL DOCKER (if not already installed)
# ============================================================================
echo -e "\n${YELLOW}[1/5] Installing Docker...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}Installing Docker...${NC}"
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed: $(docker --version)${NC}"
fi

# ============================================================================
# 2. INSTALL TERRAFORM
# ============================================================================
echo -e "\n${YELLOW}[2/5] Installing Terraform...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${BLUE}Downloading Terraform 1.7.0...${NC}"
    cd /tmp
    wget -q https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
    unzip -q terraform_1.7.0_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    rm terraform_1.7.0_linux_amd64.zip
    echo -e "${GREEN}✓ Terraform installed${NC}"
else
    TERRAFORM_VERSION=$(terraform --version | head -1)
    echo -e "${GREEN}✓ Terraform already installed: ${TERRAFORM_VERSION}${NC}"
fi

terraform --version

# ============================================================================
# 3. INSTALL ANSIBLE
# ============================================================================
echo -e "\n${YELLOW}[3/5] Installing Ansible...${NC}"

if ! command -v ansible &> /dev/null; then
    echo -e "${BLUE}Installing Ansible...${NC}"
    sudo apt-get update
    sudo apt-get install -y python3-pip
    sudo pip3 install ansible
    echo -e "${GREEN}✓ Ansible installed${NC}"
else
    echo -e "${GREEN}✓ Ansible already installed: $(ansible --version | head -1)${NC}"
fi

# ============================================================================
# 4. INSTALL TRIVY (Security Scanner)
# ============================================================================
echo -e "\n${YELLOW}[4/5] Installing Trivy...${NC}"

if ! command -v trivy &> /dev/null; then
    echo -e "${BLUE}Downloading Trivy...${NC}"
    cd /tmp
    wget -q https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.tar.gz
    tar zxf trivy_0.50.0_Linux-64bit.tar.gz
    sudo mv trivy /usr/local/bin/
    rm trivy_0.50.0_Linux-64bit.tar.gz
    echo -e "${GREEN}✓ Trivy installed${NC}"
else
    echo -e "${GREEN}✓ Trivy already installed: $(trivy --version | head -1)${NC}"
fi

# ============================================================================
# 5. INSTALL KUBECTL
# ============================================================================
echo -e "\n${YELLOW}[5/5] Installing kubectl...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${BLUE}Downloading kubectl...${NC}"
    cd /tmp
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo -e "${GREEN}✓ kubectl installed${NC}"
else
    echo -e "${GREEN}✓ kubectl already installed${NC}"
fi

# ============================================================================
# VERIFY ALL TOOLS
# ============================================================================
echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}✓ Verifying all tools...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

echo -e "${GREEN}✓ Docker:    $(docker --version)${NC}"
echo -e "${GREEN}✓ Terraform: $(terraform --version | head -1)${NC}"
echo -e "${GREEN}✓ Ansible:   $(ansible --version | head -1)${NC}"
echo -e "${GREEN}✓ Trivy:     $(trivy --version | head -1)${NC}"
echo -e "${GREEN}✓ kubectl:   $(kubectl version --client -o json 2>/dev/null | grep gitVersion | cut -d'"' -f4)${NC}"

# ============================================================================
# NEXT STEPS
# ============================================================================
echo -e "\n${YELLOW}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 Next Steps for Jenkins Setup:${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"

echo -e "\n${BLUE}1. Create Jenkins Credentials:${NC}"
echo -e "   - dockerhub-credentials (Username + Password)"
echo -e "   - aws-access-key-id (Secret text)"
echo -e "   - aws-secret-access-key (Secret text)"
echo -e "   - gemini-api-key (Secret text)"

echo -e "\n${BLUE}2. Copy SSH key to Jenkins user (if using Jenkins):${NC}"
echo -e "   sudo su - jenkins"
echo -e "   mkdir -p ~/.ssh"
echo -e "   # Copy ai-product-insights-key.pem to ~/.ssh/"
echo -e "   chmod 600 ~/.ssh/ai-product-insights-key.pem"

echo -e "\n${BLUE}3. Create Jenkins Pipeline Job:${NC}"
echo -e "   - New Item → Pipeline"
echo -e "   - Pipeline from SCM → Git"
echo -e "   - Repository: https://github.com/SAIFDINE23/ai-product-insights-platform"
echo -e "   - Branch: main"
echo -e "   - Script Path: Jenkinsfile"

echo -e "\n${BLUE}4. Test locally first (recommended):${NC}"
echo -e "   cd /home/saif/projects/Product_Insights"
echo -e "   ./test-pipeline-locally.sh"

echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tools are ready for Jenkins!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
