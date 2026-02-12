// ============================================================================
// JENKINS DECLARATIVE PIPELINE
// AI PRODUCT INSIGHTS - CI/CD DOCKER + KUBERNETES
// ============================================================================

pipeline {
    agent any
    
    // ========================================================================
    // OPTIONS PIPELINE
    // ========================================================================
    options {
        // Garder les 30 derniers builds
        buildDiscarder(logRotator(numToKeepStr: '30'))
        
        // Timeout global (30 minutes)
        timeout(time: 30, unit: 'MINUTES')
        
        // Timestamp dans les logs
        timestamps()
        
        // Disable concurrent builds
        disableConcurrentBuilds()
    }
    
    // ========================================================================
    // PARAMETERS (Peuvent être modifiés à chaque run)
    // ========================================================================
    parameters {
        choice(
            name: 'ACTION',
            choices: ['Build & Push', 'Build & Push & Deploy K8s', 'Build & Push & Deploy AWS'],
            description: 'Qu\'est-ce que vous voulez faire?'
        )
        
        choice(
            name: 'DEPLOY_TARGET',
            choices: ['kubernetes', 'aws-ec2', 'both'],
            description: 'Où déployer l\'application?'
        )
        
        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'Tag Docker pour les images (ex: latest, v1.0.0, dev)'
        )
        
        booleanParam(
            name: 'PUSH_TO_REGISTRY',
            defaultValue: true,
            description: 'Push les images vers DockerHub?'
        )
        
        booleanParam(
            name: 'SCAN_WITH_TRIVY',
            defaultValue: true,
            description: 'Scanner les images avec Trivy?'
        )
        
        booleanParam(
            name: 'TERRAFORM_DESTROY',
            defaultValue: false,
            description: 'Destroy l\'infrastructure AWS après le build? (économie Free Tier)'
        )
    }
    
    // ========================================================================
    // ENVIRONMENT VARIABLES
    // ========================================================================
    environment {
        // Registry
        REGISTRY = "docker.io"
        DOCKER_REPO = "saifdine23"
        
        // Images
        SCRAPER_IMAGE = "${DOCKER_REPO}/scraper-service:${params.IMAGE_TAG}"
        AI_ANALYSIS_IMAGE = "${DOCKER_REPO}/ai-analysis-service:${params.IMAGE_TAG}"
        STATS_IMAGE = "${DOCKER_REPO}/stats-service:${params.IMAGE_TAG}"
        FRONTEND_IMAGE = "${DOCKER_REPO}/dashboard-frontend:${params.IMAGE_TAG}"
        
        // Paths
        PROJECT_ROOT = "${WORKSPACE}"
        BACKEND_PATH = "${PROJECT_ROOT}/backend"
        FRONTEND_PATH = "${PROJECT_ROOT}/frontend/dashboard-react"
        K8S_PATH = "${PROJECT_ROOT}/k8s"
        TERRAFORM_PATH = "${PROJECT_ROOT}/infrastructure/terraform"
        ANSIBLE_PATH = "${PROJECT_ROOT}/infrastructure/ansible"
        
        // Kubernetes
        K8S_NAMESPACE = "ai-product-insights"
        KUBECONFIG = "${WORKSPACE}/.kube/config"
        
        // AWS
        AWS_REGION = "eu-west-1"
        
        // Docker buildkit (désactivé pour éviter l'erreur buildx)
        DOCKER_BUILDKIT = "0"
        COMPOSE_DOCKER_CLI_BUILD = "0"
        
        // Colors for output
        GREEN = '\033[0;32m'
        RED = '\033[0;31m'
        YELLOW = '\033[1;33m'
        BLUE = '\033[0;34m'
        NC = '\033[0m' // No Color
    }
    
    // ========================================================================
    // STAGES
    // ========================================================================
    stages {
        // ====================================================================
        // STAGE 1: CHECKOUT
        // ====================================================================
        stage('🔄 Checkout') {
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 1: GIT CHECKOUT${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                }
                
                checkout scm
                
                script {
                    // Display commit info
                    def gitCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    def gitBranch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    def gitAuthor = sh(script: 'git log -1 --pretty=%an', returnStdout: true).trim()
                    def gitMessage = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    
                    echo "${GREEN}✓ Commit: ${gitCommit}${NC}"
                    echo "${GREEN}✓ Branch: ${gitBranch}${NC}"
                    echo "${GREEN}✓ Author: ${gitAuthor}${NC}"
                    echo "${GREEN}✓ Message: ${gitMessage}${NC}"
                    
                    // Store in build description
                    currentBuild.description = "Branch: ${gitBranch}\nCommit: ${gitCommit}"
                }
            }
        }
        
        // ====================================================================
        // STAGE 2: VERIFY PREREQUISITES
        // ====================================================================
        stage('✓ Verify Prerequisites') {
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 2: VERIFY TOOLS${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    sh '''
                        echo "Docker version:"
                        docker --version
                        
                        echo ""
                        echo "Trivy version:"
                        trivy --version
                        
                        echo ""
                        echo "kubectl version:"
                        kubectl version --client
                        
                        echo ""
                        echo "Git version:"
                        git --version
                    '''
                }
            }
        }
        
        // ====================================================================
        // STAGE 3: BUILD DOCKER IMAGES
        // ====================================================================
        stage('🔨 Build Docker Images') {
            parallel {
                stage('Build Scraper') {
                    steps {
                        script {
                            echo "${YELLOW}Building scraper-service:${params.IMAGE_TAG}...${NC}"
                            sh '''
                                cd ${BACKEND_PATH}/scraper-service
                                docker build -t ${SCRAPER_IMAGE} .
                                echo "${GREEN}✓ Scraper image built${NC}"
                            '''
                        }
                    }
                }
                
                stage('Build AI Analysis') {
                    steps {
                        script {
                            echo "${YELLOW}Building ai-analysis-service:${params.IMAGE_TAG}...${NC}"
                            sh '''
                                cd ${BACKEND_PATH}/ai-analysis-service
                                docker build -t ${AI_ANALYSIS_IMAGE} .
                                echo "${GREEN}✓ AI Analysis image built${NC}"
                            '''
                        }
                    }
                }
                
                stage('Build Stats') {
                    steps {
                        script {
                            echo "${YELLOW}Building stats-service:${params.IMAGE_TAG}...${NC}"
                            sh '''
                                cd ${BACKEND_PATH}/stats-service
                                docker build -t ${STATS_IMAGE} .
                                echo "${GREEN}✓ Stats image built${NC}"
                            '''
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        script {
                            echo "${YELLOW}Building dashboard-frontend:${params.IMAGE_TAG}...${NC}"
                            sh '''
                                cd ${FRONTEND_PATH}
                                docker build -t ${FRONTEND_IMAGE} .
                                echo "${GREEN}✓ Frontend image built${NC}"
                            '''
                        }
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 4: SCAN WITH TRIVY
        // ====================================================================
        stage('🔍 Security Scan (Trivy)') {
            when {
                expression { params.SCAN_WITH_TRIVY == true }
            }
            parallel {
                stage('Scan Scraper') {
                    steps {
                        script {
                            echo "${YELLOW}Scanning scraper-service...${NC}"
                            sh '''
                                trivy image --severity HIGH,CRITICAL ${SCRAPER_IMAGE} || true
                                echo "${GREEN}✓ Scraper scan completed${NC}"
                            '''
                        }
                    }
                }
                
                stage('Scan AI Analysis') {
                    steps {
                        script {
                            echo "${YELLOW}Scanning ai-analysis-service...${NC}"
                            sh '''
                                trivy image --severity HIGH,CRITICAL ${AI_ANALYSIS_IMAGE} || true
                                echo "${GREEN}✓ AI Analysis scan completed${NC}"
                            '''
                        }
                    }
                }
                
                stage('Scan Stats') {
                    steps {
                        script {
                            echo "${YELLOW}Scanning stats-service...${NC}"
                            sh '''
                                trivy image --severity HIGH,CRITICAL ${STATS_IMAGE} || true
                                echo "${GREEN}✓ Stats scan completed${NC}"
                            '''
                        }
                    }
                }
                
                stage('Scan Frontend') {
                    steps {
                        script {
                            echo "${YELLOW}Scanning dashboard-frontend...${NC}"
                            sh '''
                                trivy image --severity HIGH,CRITICAL ${FRONTEND_IMAGE} || true
                                echo "${GREEN}✓ Frontend scan completed${NC}"
                            '''
                        }
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 5: PUSH TO REGISTRY
        // ====================================================================
        stage('📤 Push to Registry') {
            when {
                expression { params.PUSH_TO_REGISTRY == true }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 5: PUSH IMAGES TO DOCKERHUB${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh '''
                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                            echo "${GREEN}✓ Docker login successful${NC}"
                            
                            echo ""
                            echo "${YELLOW}Pushing images...${NC}"
                            docker push ${SCRAPER_IMAGE}
                            echo "${GREEN}✓ Scraper pushed${NC}"
                            
                            docker push ${AI_ANALYSIS_IMAGE}
                            echo "${GREEN}✓ AI Analysis pushed${NC}"
                            
                            docker push ${STATS_IMAGE}
                            echo "${GREEN}✓ Stats pushed${NC}"
                            
                            docker push ${FRONTEND_IMAGE}
                            echo "${GREEN}✓ Frontend pushed${NC}"
                            
                            docker logout
                            echo "${GREEN}✓ All images pushed successfully${NC}"
                        '''
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 6: DEPLOY TO KUBERNETES
        // ====================================================================
        stage('🚀 Deploy to Kubernetes') {
            when {
                expression { 
                    params.ACTION.contains('Deploy K8s') || 
                    params.DEPLOY_TARGET == 'kubernetes' || 
                    params.DEPLOY_TARGET == 'both'
                }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 6: KUBERNETES DEPLOYMENT${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"

                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        sh '''
                            export KUBECONFIG=${KUBECONFIG_FILE}

                            echo "${YELLOW}Checking kubectl connectivity...${NC}"
                            kubectl cluster-info

                            echo ""
                            echo "${YELLOW}Current namespace: ${K8S_NAMESPACE}${NC}"

                            echo ""
                            echo "${YELLOW}Deploying to Kubernetes...${NC}"

                            # Create namespace if not exists
                            kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                            # Apply secrets
                            kubectl apply -f ${K8S_PATH}/secrets.yaml -n ${K8S_NAMESPACE}

                            # Apply deployments
                            kubectl apply -f ${K8S_PATH}/ -n ${K8S_NAMESPACE}

                            # Wait for rollout
                            kubectl rollout status deployment/ai-analysis-service -n ${K8S_NAMESPACE} --timeout=5m || true

                            echo "${GREEN}✓ Kubernetes deployment completed${NC}"
                        '''
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 7: TERRAFORM - PROVISION AWS INFRASTRUCTURE
        // ====================================================================
        stage('🏗️ Terraform - Provision AWS') {
            when {
                expression { 
                    params.ACTION.contains('Deploy AWS') || 
                    params.DEPLOY_TARGET == 'aws-ec2' || 
                    params.DEPLOY_TARGET == 'both'
                }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 7: TERRAFORM INFRASTRUCTURE PROVISIONING${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            cd ${TERRAFORM_PATH}
                            
                            echo "${YELLOW}Initializing Terraform...${NC}"
                            terraform init
                            
                            echo ""
                            echo "${YELLOW}Validating Terraform configuration...${NC}"
                            terraform validate
                            
                            echo ""
                            echo "${YELLOW}Planning Terraform changes...${NC}"
                            terraform plan -var-file=terraform.tfvars -out=tfplan
                            
                            echo ""
                            echo "${YELLOW}Applying Terraform configuration...${NC}"
                            terraform apply -auto-approve tfplan
                            
                            echo ""
                            echo "${YELLOW}Extracting EC2 Public IP...${NC}"
                            export EC2_PUBLIC_IP=$(terraform output -raw instance_public_ip)
                            echo "EC2_PUBLIC_IP=${EC2_PUBLIC_IP}" > ${WORKSPACE}/ec2_ip.env
                            echo "${GREEN}✓ EC2 Public IP: ${EC2_PUBLIC_IP}${NC}"
                            
                            # Update Ansible inventory
                            echo ""
                            echo "${YELLOW}Updating Ansible inventory...${NC}"
                            cat > ${ANSIBLE_PATH}/inventory.ini <<EOF
[ec2_instances]
ec2-app ansible_host=${EC2_PUBLIC_IP} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/ai-product-insights-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
                            echo "${GREEN}✓ Inventory updated${NC}"
                        '''
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 8: ANSIBLE - DEPLOY APPLICATION TO AWS
        // ====================================================================
        stage('📦 Ansible - Deploy to AWS') {
            when {
                expression { 
                    params.ACTION.contains('Deploy AWS') || 
                    params.DEPLOY_TARGET == 'aws-ec2' || 
                    params.DEPLOY_TARGET == 'both'
                }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 8: ANSIBLE APPLICATION DEPLOYMENT${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    withCredentials([
                        string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')
                    ]) {
                        sh '''
                            cd ${ANSIBLE_PATH}
                            
                            # Load EC2 IP
                            source ${WORKSPACE}/ec2_ip.env
                            
                            echo "${YELLOW}Waiting 60s for EC2 instance to be ready...${NC}"
                            sleep 60
                            
                            echo ""
                            echo "${YELLOW}Testing SSH connectivity...${NC}"
                            ansible all -i inventory.ini -m ping || (echo "SSH not ready yet, waiting another 30s..." && sleep 30 && ansible all -i inventory.ini -m ping)
                            
                            echo ""
                            echo "${YELLOW}Running Ansible playbook...${NC}"
                            ansible-playbook -i inventory.ini playbook.yml -e "gemini_api_key=${GEMINI_API_KEY}" -vv
                            
                            echo ""
                            echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
                            echo "${GREEN}✓ APPLICATION DEPLOYED SUCCESSFULLY${NC}"
                            echo "${GREEN}✓ Frontend URL: http://${EC2_PUBLIC_IP}${NC}"
                            echo "${GREEN}✓ Backend API: http://${EC2_PUBLIC_IP}:8000${NC}"
                            echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
                        '''
                    }
                }
            }
        }
        
        // ====================================================================
        // STAGE 9: TERRAFORM DESTROY (Optional - Save Free Tier)
        // ====================================================================
        stage('🗑️ Terraform Destroy (Cleanup)') {
            when {
                expression { params.TERRAFORM_DESTROY == true }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 9: TERRAFORM DESTROY (Free Tier Cleanup)${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            cd ${TERRAFORM_PATH}
                            
                            echo "${YELLOW}Destroying AWS infrastructure...${NC}"
                            terraform destroy -var-file=terraform.tfvars -auto-approve
                            
                            echo "${GREEN}✓ Infrastructure destroyed${NC}"
                        '''
                    }
                }
            }
        }
    }
    
    // ========================================================================
    // POST ACTIONS
    // ========================================================================
    post {
        always {
            script {
                echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                echo "${BLUE}PIPELINE POST ACTIONS${NC}"
                echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                
                // Cleanup (safe)
                sh '''
                    echo "${YELLOW}Cleaning up...${NC}"
                    docker image prune -f || true
                    echo "${GREEN}✓ Cleanup completed${NC}"
                '''
            }
        }
        
        success {
            script {
                echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
                echo "${GREEN}✓ PIPELINE SUCCEEDED${NC}"
                echo "${GREEN}═══════════════════════════════════════════════════════${NC}"
                
                // Optional: Slack notification
                // slackSend(
                //     color: 'good',
                //     message: "✓ Pipeline successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                // )
            }
        }
        
        failure {
            script {
                echo "${RED}═══════════════════════════════════════════════════════${NC}"
                echo "${RED}✗ PIPELINE FAILED${NC}"
                echo "${RED}═══════════════════════════════════════════════════════${NC}"
                
                // Optional: Slack notification
                // slackSend(
                //     color: 'danger',
                //     message: "✗ Pipeline failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                // )
            }
        }
        
        unstable {
            script {
                echo "${YELLOW}⚠ Pipeline unstable${NC}"
            }
        }
    }
}
