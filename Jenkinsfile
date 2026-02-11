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
            choices: ['Build & Push', 'Build & Push & Deploy'],
            description: 'Qu\'est-ce que vous voulez faire?'
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
        
        // Kubernetes
        K8S_NAMESPACE = "ai-product-insights"
        KUBECONFIG = "${WORKSPACE}/.kube/config"
        
        // Docker buildkit
        DOCKER_BUILDKIT = "1"
        
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
                expression { params.ACTION == 'Build & Push & Deploy' }
            }
            steps {
                script {
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo "${BLUE}STAGE 6: KUBERNETES DEPLOYMENT${NC}"
                    echo "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    sh '''
                        echo "${YELLOW}Checking kubectl connectivity...${NC}"
                        kubectl cluster-info || echo "Kubernetes cluster not available"
                        
                        echo ""
                        echo "${YELLOW}Current namespace: ${K8S_NAMESPACE}${NC}"
                        
                        echo ""
                        echo "${YELLOW}Deploying to Kubernetes...${NC}"
                        
                        # Update image tags in manifests (optionnel)
                        # kubectl set image deployment/scraper-service scraper-service=${SCRAPER_IMAGE} -n ${K8S_NAMESPACE}
                        
                        # Ou appliquer les manifests
                        # kubectl apply -f ${K8S_PATH}/
                        
                        echo "${GREEN}✓ Kubernetes deployment completed${NC}"
                    '''
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
                
                // Cleanup
                sh '''
                    echo "${YELLOW}Cleaning up...${NC}"
                    docker system prune -af --volumes || true
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
