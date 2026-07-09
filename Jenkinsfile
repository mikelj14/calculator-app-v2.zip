pipeline {
    // 1. Force all build/CI steps to run inside a managed Docker agent environment
    agent {
        docker { 
            image 'python:3.10-slim'
            args '-u root' 
        }
    }

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION    = 'us-east-1' 
        AWS_ACCOUNT_ID        = '992382545251' 
        IMAGE_NAME            = 'calculator-app'
        ECR_REGISTRY          = '992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator'
        EC2_PUBLIC_IP         = '3.84.115.81'
        
        // 3. Generate a deterministic tag based on whether it is a PR or a Main merge build
        IMAGE_TAG = "${CHANGE_ID ? 'pr-' + CHANGE_ID + '-' + BUILD_NUMBER : 'release-' + BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                echo "Building production image: ${IMAGE_NAME}:${IMAGE_TAG}"
                // Interacts with host docker daemon sidecar setup
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Run Containerized Tests') {
            steps {
                echo 'Executing unit tests and exporting results...'
                // 2 & 5. Runs pytest and exports standard JUnit XML reports out of the container
                sh "docker run --rm -v \$(pwd):/reports -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG} pytest --junitxml=/reports/test-results.xml"
            }
        }

        stage('Push to AWS ECR') {
            steps {
                echo 'Authenticating with AWS ECR...'
                sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                
                echo "4. Pushing explicit deterministic reference to ECR: ${ECR_REGISTRY}:${IMAGE_TAG}"
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:${IMAGE_TAG}"
                sh "docker push ${ECR_REGISTRY}:${IMAGE_TAG}"
                
                // Keep latest tag updated
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:latest"
                sh "docker push ${ECR_REGISTRY}:latest"
            }
        }

        stage('Deploy to Production EC2') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                echo 'Deploying fresh container version to Production EC2...'
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh """
                       ECR_TOKEN=\$(aws ecr get-login-password --region us-east-1)
                       ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${EC2_PUBLIC_IP} "
                           echo \$ECR_TOKEN | docker login --username AWS --password-stdin 992382545251.dkr.ecr.us-east-1.amazonaws.com
                           docker pull ${ECR_REGISTRY}:latest
                           docker stop ${IMAGE_NAME} || true
                           docker rm ${IMAGE_NAME} || true
                           docker run -d --name ${IMAGE_NAME} -p 80:5000 ${ECR_REGISTRY}:latest
                       "
                    """
                }
            }
        }

        stage('Health Verification') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                echo 'Executing application health check...'
                sh "curl --fail http://${EC2_PUBLIC_IP}/ || exit 1"
            }
        }
    }

    post {
        always {
            // 5. Ingest and display test summaries in the Jenkins UI dashboard, then clear workspace
            junit allowEmptyResults: true, testResults: 'test-results.xml'
            cleanWs() 
        }
    }
}
