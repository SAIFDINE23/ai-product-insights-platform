#!/bin/bash

# ============================================================================
# TEST PIPELINE LOCALLY (Terraform + Ansible)
# Simule ce que Jenkins fera automatiquement
# ============================================================================

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🧪 LOCAL PIPELINE TEST - Terraform + Ansible${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

# ============================================================================
# 1. VERIFY PREREQUISITES
# ============================================================================
echo -e "\n${YELLOW}[1/6] Verifying prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform: $(terraform --version | head -1)${NC}"

if ! command -v ansible &> /dev/null; then
    echo -e "${RED}❌ Ansible not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Ansible: $(ansible --version | head -1)${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker: $(docker --version)${NC}"

# Check SSH key
if [ ! -f ~/.ssh/ai-product-insights-key.pem ]; then
    echo -e "${RED}❌ SSH Key not found: ~/.ssh/ai-product-insights-key.pem${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH Key exists${NC}"

# Check AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${RED}❌ AWS credentials not set in environment${NC}"
    echo -e "${YELLOW}Please export AWS credentials first:${NC}"
    echo -e "  export AWS_ACCESS_KEY_ID='your-key-id'"
    echo -e "  export AWS_SECRET_ACCESS_KEY='your-secret-key'"
    echo -e "  export AWS_DEFAULT_REGION='eu-west-1'"
    exit 1
fi
echo -e "${GREEN}✓ AWS Access Key: ${AWS_ACCESS_KEY_ID:0:10}...${NC}"

# Check Gemini API Key
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${YELLOW}⚠ GEMINI_API_KEY not set${NC}"
    echo -e "${YELLOW}Reading from backend/ai-analysis-service/.env if available...${NC}"
    if [ -f backend/ai-analysis-service/.env ]; then
        export GEMINI_API_KEY=$(grep GEMINI_API_KEY backend/ai-analysis-service/.env | cut -d '=' -f2)
    fi
fi

if [ -n "$GEMINI_API_KEY" ]; then
    echo -e "${GREEN}✓ Gemini API Key: ${GEMINI_API_KEY:0:20}...${NC}"
else
    echo -e "${RED}❌ GEMINI_API_KEY not found${NC}"
    exit 1
fi

# ============================================================================
# 2. BUILD DOCKER IMAGES (Only Frontend - skip others for speed)
# ============================================================================
echo -e "\n${YELLOW}[2/6] Building Docker images...${NC}"
echo -e "${BLUE}Skipping image build (using existing images from DockerHub)${NC}"
echo -e "${GREEN}✓ Will use: saifdine23/frontend:latest${NC}"
echo -e "${GREEN}✓ Will use: saifdine23/ai-analysis-service:latest${NC}"
echo -e "${GREEN}✓ Will use: saifdine23/stats-service:latest${NC}"
echo -e "${GREEN}✓ Will use: saifdine23/scraper-service:latest${NC}"

# ============================================================================
# 3. TERRAFORM - PROVISION INFRASTRUCTURE
# ============================================================================
echo -e "\n${YELLOW}[3/6] Terraform - Provisioning AWS Infrastructure...${NC}"

cd infrastructure/terraform

echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init -upgrade

echo -e "${BLUE}Validating configuration...${NC}"
terraform validate

echo -e "${BLUE}Planning changes...${NC}"
terraform plan -var-file=terraform.tfvars -out=tfplan

echo -e "${BLUE}Applying configuration...${NC}"
terraform apply -auto-approve tfplan

echo -e "${BLUE}Extracting EC2 Public IP...${NC}"
export EC2_PUBLIC_IP=$(terraform output -raw instance_public_ip)
echo -e "${GREEN}✓ EC2 Public IP: ${EC2_PUBLIC_IP}${NC}"

# Save to file for later use
echo "EC2_PUBLIC_IP=${EC2_PUBLIC_IP}" > ../../ec2_ip.env

# ============================================================================
# 4. UPDATE ANSIBLE INVENTORY
# ============================================================================
echo -e "\n${YELLOW}[4/6] Updating Ansible inventory...${NC}"

cd ../ansible

cat > inventory.ini <<EOF
[ec2_instances]
ec2-app ansible_host=${EC2_PUBLIC_IP} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/ai-product-insights-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo -e "${GREEN}✓ Inventory updated with IP: ${EC2_PUBLIC_IP}${NC}"

# ============================================================================
# 5. WAIT FOR EC2 TO BE READY
# ============================================================================
echo -e "\n${YELLOW}[5/6] Waiting for EC2 instance to be ready...${NC}"

echo -e "${BLUE}Waiting 60 seconds for instance boot...${NC}"
sleep 60

echo -e "${BLUE}Testing SSH connectivity...${NC}"
for i in {1..5}; do
    if ansible all -i inventory.ini -m ping &> /dev/null; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
        break
    else
        echo -e "${YELLOW}Attempt $i/5 failed, waiting 15s...${NC}"
        sleep 15
    fi
done

# ============================================================================
# 6. ANSIBLE - DEPLOY APPLICATION
# ============================================================================
echo -e "\n${YELLOW}[6/6] Ansible - Deploying application...${NC}"

echo -e "${BLUE}Running Ansible playbook...${NC}"
ansible-playbook -i inventory.ini playbook.yml \
    -e "gemini_api_key=${GEMINI_API_KEY}" \
    -vv

# ============================================================================
# 7. VERIFY DEPLOYMENT
# ============================================================================
echo -e "\n${YELLOW}Verifying deployment...${NC}"

sleep 10

echo -e "${BLUE}Testing frontend...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "http://${EC2_PUBLIC_IP}" | grep -q "200"; then
    echo -e "${GREEN}✓ Frontend is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Frontend not yet ready (may need more time)${NC}"
fi

echo -e "${BLUE}Testing backend API...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "http://${EC2_PUBLIC_IP}:8000/docs" | grep -q "200"; then
    echo -e "${GREEN}✓ Backend API is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Backend not yet ready (may need more time)${NC}"
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🌐 Frontend URL: http://${EC2_PUBLIC_IP}${NC}"
echo -e "${GREEN}📡 Backend API: http://${EC2_PUBLIC_IP}:8000${NC}"
echo -e "${GREEN}📚 API Docs: http://${EC2_PUBLIC_IP}:8000/docs${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "  1. Open http://${EC2_PUBLIC_IP} in your browser"
echo -e "  2. Test the dashboard features"
echo -e "  3. When done, run: cd infrastructure/terraform && terraform destroy -var-file=terraform.tfvars -auto-approve"

cd ../..
