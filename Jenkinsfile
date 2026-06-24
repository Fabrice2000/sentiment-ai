pipeline {
    agent any

    environment {
        IMAGE_NAME = 'sentiment-ai'
        REGISTRY = 'ghcr.io/fabrice2000'
        IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Branche : ${env.BRANCH_NAME}"
                echo "Commit : ${env.GIT_COMMIT}"
                sh 'git log --oneline -5'
            }
        }

        stage('Lint') {
            steps {
                sh 'docker run --rm --volumes-from jenkins -w $WORKSPACE python:3.12-slim sh -c "pip install flake8 -q && flake8 src/ --max-line-length=100"'
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker rm -f test-runner 2>/dev/null || true
                    set +e
                    docker run -e CI=true --name test-runner ${IMAGE_NAME}:${IMAGE_TAG} pytest tests/ -v --cov=src --cov-report=xml:/tmp/coverage.xml --cov-report=term-missing --cov-fail-under=70
                    TEST_EXIT_CODE=$?
                    set -e
                    docker cp test-runner:/tmp/coverage.xml ./coverage.xml 2>/dev/null || true
                    docker rm -f test-runner 2>/dev/null || true
                    sed -i "s|/app/src|src|g" coverage.xml || true
                    sed -i "s|<source>/app</source>|<source>.</source>|g" coverage.xml || true
                    exit $TEST_EXIT_CODE
                '''
            }
            post {
                failure {
                    echo 'Tests echoues ou coverage insuffisant (< 70%)'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'docker run --rm --network cicd-network --volumes-from jenkins -w $WORKSPACE -e SONAR_HOST_URL=$SONAR_HOST_URL -e SONAR_TOKEN=$SONAR_AUTH_TOKEN sonarsource/sonar-scanner-cli:latest sonar-scanner -Dsonar.projectKey=sentiment-ai -Dsonar.projectName=SentimentAI -Dsonar.sources=src -Dsonar.python.version=3.11 -Dsonar.python.coverage.reportPaths=coverage.xml -Dsonar.sourceEncoding=UTF-8 -Dsonar.scanner.metadataFilePath=$WORKSPACE/report-task.txt'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy aquasec/trivy:latest image --severity HIGH,CRITICAL --exit-code 0 --format table ${IMAGE_NAME}:${IMAGE_TAG}'
            }
            post {
                failure {
                    echo 'Vulnerabilites CRITICAL ou HIGH detectees !'
                }
            }
        }

        stage('Push') {
            when { expression { env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main' } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASS')]) {
                    sh '''
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        echo $REGISTRY_PASS | docker login ghcr.io -u $REGISTRY_USER --password-stdin
                        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:latest
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Deploy Staging') {
            when { expression { env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main' } }
            steps {
                echo "Deploiement de ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} en staging..."
                sh '''
                    docker compose -p staging -f docker-compose.yml down 2>/dev/null || true
                    docker compose -p staging -f docker-compose.yml up -d
                    echo "Staging disponible sur http://localhost:8001"
                '''
            }
        }

    }

    post {
        always {
            sh 'docker compose down -v 2>/dev/null || true'
        }
        success {
            echo "Pipeline reussi ! Image : ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline echoue. Consultez les logs ci-dessus.'
        }
    }
}
