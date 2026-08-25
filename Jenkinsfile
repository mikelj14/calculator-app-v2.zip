pipeline {
    agent none

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION    = 'us-east-1'
        AWS_ACCOUNT_ID        = '992382545251'
        IMAGE_NAME            = 'calculator-app'
        ECR_REGISTRY          = '992382545251.dkr.ecr.us-east-1.amazonaws.com/ilan-calculator'
        EC2_PUBLIC_IP         = '54.88.230.221'
        IMAGE_TAG             = "${env.CHANGE_ID ? 'pr-' + env.CHANGE_ID + '-' + env.BUILD_NUMBER : 'release-' + env.BUILD_NUMBER}"
    }

    stages {

        // Stage 1: Build Container Image
        stage('Build Container Image') {
            agent {
                docker {
                    image 'python:3.10-slim'
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker --entrypoint=""'
                }
            }

            steps {
                checkout scm

                echo "Building image reference: ${IMAGE_NAME}:${IMAGE_TAG}"

                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        // Stage 2: Test
        stage('Test') {
            agent {
                docker {
                    image 'python:3.10-slim'
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker --entrypoint=""'
                }
            }

            steps {
                checkout scm

                echo "Executing verification tests for build reference: ${IMAGE_NAME}:${IMAGE_TAG}"

                sh """
                    CONTAINER_ID=\$(hostname)

                    docker run --rm \
                      --volumes-from "\${CONTAINER_ID}" \
                      -w "\$(pwd)" \
                      -e PYTHONPATH=/app \
                      ${IMAGE_NAME}:${IMAGE_TAG} \
                      pytest --junitxml="\$(pwd)/test-results.xml"
                """
            }
        }

        // Stage 3: Provision Infrastructure
        stage('Provision Infrastructure') {
            when {
                beforeAgent true
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }

            agent any

            steps {
                checkout scm

                echo 'Provisioning infrastructure with Terraform...'

                sh '''
                    echo "========================================="
                    echo "Current workspace:"
                    pwd
                    echo "========================================="

                    ls -la

                    echo "========================================="
                    echo "Terraform configuration files:"
                    find . -maxdepth 1 -name "*.tf" -print
                    echo "========================================="

                    CONTAINER_ID=$(hostname)

                    docker run --rm \
                      --volumes-from "${CONTAINER_ID}" \
                      -w "$(pwd)" \
                      -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
                      -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
                      -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
                      hashicorp/terraform:latest init

                    docker run --rm \
                      --volumes-from "${CONTAINER_ID}" \
                      -w "$(pwd)" \
                      -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
                      -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
                      -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
                      hashicorp/terraform:latest apply -auto-approve
                '''
            }
        }

        // Stage 4: Push to ECR
        stage('Push to ECR') {
            agent {
                docker {
                    image 'amazon/aws-cli:latest'
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker --entrypoint=""'
                }
            }

            steps {
                echo "Authenticating and pushing image: ${ECR_REGISTRY}:${IMAGE_TAG}"

                sh "aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"

                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:${IMAGE_TAG}"

                sh "docker push ${ECR_REGISTRY}:${IMAGE_TAG}"

                sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}:latest"

                sh "docker push ${ECR_REGISTRY}:latest"
            }
        }

        // Stage 5: Deploy to Production EC2
        stage('Deploy to Production EC2') {
            when {
                beforeAgent true
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }

            agent {
                docker {
                    image 'amazon/aws-cli:latest'
                    args '-u root -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker --entrypoint=""'
                }
            }

            steps {
                echo 'Deploying fresh container version to Production EC2...'

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "Installing SSH client..."
                        yum install -y openssh-clients

                        echo "Getting ECR authentication token..."

                        # --- sensitive section: no command echoing while the token exists ---
                        set +x
                        ECR_TOKEN=$(aws ecr get-login-password --region "${AWS_DEFAULT_REGION}")

                        echo "Connecting to production EC2..."

                        # Pipe the token in via stdin instead of embedding it in the remote
                        # command string, so it never appears as literal text in this script,
                        # in Jenkins' console output, or in `ps` output on either host.
                        echo "$ECR_TOKEN" | ssh \
                            -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "$SSH_USER@$EC2_PUBLIC_IP" \
                            "docker login --username AWS --password-stdin '${ECR_REGISTRY}'"

                        unset ECR_TOKEN
                        set -x
                        # --- end sensitive section ---

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "$SSH_USER@$EC2_PUBLIC_IP" \
                            "docker pull '${ECR_REGISTRY}:latest' && \
                             docker stop '${IMAGE_NAME}' || true"

                        ssh \
                            -o StrictHostKeyChecking=no \
                            -i "$SSH_KEY" \
                            "$SSH_USER@$EC2_PUBLIC_IP" \
                            "docker rm '${IMAGE_NAME}' || true && \
                             docker run -d \
                               --name '${IMAGE_NAME}' \
                               -p 80:5000 \
                               '${ECR_REGISTRY}:latest'"
                    '''
                }
            }
        }

        // Stage 6: Health Verification
        stage('Health Verification') {
            when {
                beforeAgent true
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }

            agent {
                docker {
                    image 'curlimages/curl:latest'
                }
            }

            steps {
                echo 'Executing application health check loop against /health endpoint...'

                sh '''
                    SUCCESS=0

                    for i in $(seq 1 5); do
                        echo "Probing endpoint check attempt $i..."

                        if curl --fail "http://${EC2_PUBLIC_IP}/health"; then
                            echo "App container is fully responding and healthy!"
                            SUCCESS=1
                            break
                        fi

                        echo "App not listening yet. Retrying in 5 seconds..."
                        sleep 5
                    done

                    if [ "$SUCCESS" -ne 1 ]; then
                        echo "Health check failed after multiple attempts."
                        exit 1
                    fi
                '''
            }
        }
    }

    post {
        always {
            node('') {
                junit allowEmptyResults: true, testResults: 'test-results.xml'
                archiveArtifacts artifacts: 'test-results.xml', allowEmptyArchive: true
                cleanWs()
            }
        }
    }
}
