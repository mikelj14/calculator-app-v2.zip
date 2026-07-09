pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION    = 'us-east-1' // Change to your AWS region
        AWS_ACCOUNT_ID        = '992382545251' // Replace with your 12-digit AWS Account ID
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
                // Spins up the built image to run tests internally, ensuring the image environment works
                sh 'docker run --rm -e PYTHONPATH=/app calculator-app:latest pytest'
                // Note: If Python/pytest app, change "npm test" to "pytest"
            }
        }

stage('Push to AWS ECR') {
    steps {
        echo 'Authenticating with AWS ECR...'
        sh 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator'
        
        echo "Tagging and pushing image version #${BUILD_NUMBER} to ECR repository..."
        // Tag and push as latest
        sh 'docker tag calculator-app:latest 992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator:latest'
        sh 'docker push 992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator:latest'
        
        // Tag and push with the unique Jenkins build number
        sh "docker tag calculator-app:latest 992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator:build-${BUILD_NUMBER}"
        sh "docker push 992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator:build-${BUILD_NUMBER}"
    }
}

    post {
        always {
        cleanWs() // Automatically cleans up the workspace folder inside Jenkins after execution
        }
    }
}
