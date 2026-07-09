pipeline {
    agent none 

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION    = 'us-east-1' 
        AWS_ACCOUNT_ID        = '992382545251' 
        IMAGE_NAME            = 'calculator-app'
        ECR_REGISTRY          = '992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator'
        EC2_PUBLIC_IP         = '3.84.115.81'
        IMAGE_TAG             = "${env.CHANGE_ID ? 'pr-' + env.CHANGE_ID + '-' + env.BUILD_NUMBER : 'release-' + env.BUILD_NUMBER}"
    }

    stages {
        // ==========================================
        // CI STAGES (Runs on Host for Docker-in-Docker engine access)
        // ==========================================
        stage('Build Container Image') {
            agent any
            steps {
                checkout scm
                echo "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Test') {
            agent any
            steps {
                echo 'Executing unit tests...'
                sh "docker run --rm -v \$(pwd):/reports -e PYTHONPATH=/app ${IMAGE_NAME}:${IMAGE_TAG} pytest --junitxml=/reports/test-results.xml"
            }
        }

        stage('Push to ECR') {
            agent any
            steps {
                echo 'Authenticating and pushing to AWS ECR...'
                sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:${IMAGE_TAG}"
                sh "docker push ${ECR_REGISTRY}:${IMAGE_TAG}"
                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:latest"
                sh "docker push ${ECR_REGISTRY}:latest"
            }
        }

        // ==========================================
        // CD STAGES (Complies with DoD: Runs inside Docker Agent Containers)
        // ==========================================
        stage('Deploy to Production EC2') {
            when { anyOf { branch 'main'; branch 'master' } }
            agent { 
                docker { 
                    image 'amazon/aws-cli:latest'
                    // Mounts host binary capabilities and the docker communication socket
                    args '-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker --entrypoint=""'
                } 
            }
            steps {
                echo 'Deploying fresh container version to Production EC2...'
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh """
                       # Install standard ssh binaries inside the container engine environment
                       yum install -y openssh-clients
                       
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
            when { anyOf { branch 'main'; branch 'master' } }
            agent { docker { image 'badouralix/curl:latest' } } 
            steps {
                echo 'Executing application health check loop against /health endpoint...'
                sh """
                   SUCCESS=0
                   for i in {1..5}; do
                       echo "Probing endpoint check attempt \$i..."
                       if curl --fail http://${EC2_PUBLIC_IP}/health; then
                           echo "App container is fully responding and healthy!"
                           SUCCESS=1
                           break
                       fi
                       echo "App not listening yet. Retrying in 5 seconds..."
                       sleep 5
                   done
                   
                   if [ \$SUCCESS -ne 1 ]; then
                       echo "Health check failed after multiple attempts."
                       exit 1
                   fi
                """
            }
        }
    }

    post {
        always {
            node('') {
                // Ingests the output results cleanly using baseline built-in agent contexts
                junit allowEmptyResults: true, testResults: 'test-results.xml'
                cleanWs()
            }
        }
    }
}
