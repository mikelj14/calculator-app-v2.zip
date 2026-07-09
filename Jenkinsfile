pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION    = 'us-east-1' 
        AWS_ACCOUNT_ID        = '992382545251' 
        IMAGE_NAME            = 'calculator-app'
        IMAGE_TAG             = 'latest'
        ECR_REGISTRY          = '992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator'
        EC2_PUBLIC_IP         = '3.84.115.81'
    }

    stages {
        // ==========================================
        // COMMON STAGES (Runs on both PRs and Main)
        // ==========================================
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                echo 'Building production Docker image...'
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Run Containerized Tests') {
            steps {
                echo 'Spinning up test container to execute unit tests...'
                sh "docker run --rm -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG} pytest"
            }
        }

        stage('Push to AWS ECR') {
            steps {
                echo 'Authenticating with AWS ECR...'
                sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                
                echo "Tagging and pushing image version build-${BUILD_NUMBER} to ECR..."
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:latest"
                sh "docker push ${ECR_REGISTRY}:latest"
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:build-${BUILD_NUMBER}"
                sh "docker push ${ECR_REGISTRY}:build-${BUILD_NUMBER}"
            }
        }

        // ==========================================
        // CD STAGES (ONLY runs when merged to main/master)
        // ==========================================
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
                       ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${EC2_PUBLIC_IP} '
                           aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 992382545251.dkr.ecr.us-east-1.amazonaws.com
                           docker pull ${ECR_REGISTRY}:latest
                           docker stop ${IMAGE_NAME} || true
                           docker rm ${IMAGE_NAME} || true
                           docker run -d --name ${IMAGE_NAME} -p 80:5000 ${ECR_REGISTRY}:latest
                       '
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
            cleanWs() 
        }
    }
}
