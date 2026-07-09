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
    }

    stages {
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
                
                echo "Tagging and pushing image version build-${BUILD_NUMBER} to ECR repository..."
                
                // Tag and push as latest
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:latest"
                sh "docker push ${ECR_REGISTRY}:latest"
                
                // Tag and push with the unique Jenkins build number
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:build-${BUILD_NUMBER}"
                sh "docker push ${ECR_REGISTRY}:build-${BUILD_NUMBER}"
            }
        }
    }

    post {
        always {
            cleanWs() 
        }
    }
}
