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
                sh 'git log --oneline -3'
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker rm -f test-runner 2>/dev/null || true
                    set +e
                    docker run -e CI=true --name test-runner ${IMAGE_NAME}:${IMAGE_TAG} pytest tests/ -v --cov=src --cov-report=xml:/tmp/coverage.xml --cov-fail-under=70
                    TEST_EXIT_CODE=$?
                    set -e
                    docker cp test-runner:/tmp/coverage.xml ./coverage.xml 2>/dev/null || true
                    docker rm -f test-runner 2>/dev/null || true
                    sed -i "s|/app/src|src|g" coverage.xml || true
                    sed -i "s|<source>/app</source>|<source>.</source>|g" coverage.xml || true
                    exit $TEST_EXIT_CODE
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'echo "LEN:"; printf "%s" "$SONAR_AUTH_TOKEN" | wc -c; echo "TEST:"; docker run --rm --network cicd-network --volumes-from jenkins -w "$WORKSPACE" sonarsource/sonar-scanner-cli:latest sonar-scanner -Dsonar.projectKey=sentiment-ai -Dsonar.sources=src -Dsonar.host.url=http://sonarqube:9000 -Dsonar.login="$SONAR_AUTH_TOKEN" 2>&1 | tail -6'
                }
            }
        }
    }

    post {
        always {
            sh 'docker compose down -v 2>/dev/null || true'
        }
    }
}
