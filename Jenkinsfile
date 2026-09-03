pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        LMS_HOST = '172.31.8.158'
        LMS_USER = 'ubuntu'
        LMS_URL = 'http://172.31.8.158'
        SSH_CREDENTIALS = 'lms-ssh-key'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '======================================'
                echo 'Checking out LMS source code'
                echo '======================================'

                checkout scm

                sh '''
                    echo "Git commit:"
                    git rev-parse HEAD

                    echo "Repository files:"
                    ls -la
                '''
            }
        }

        stage('Validate') {
            steps {
                echo 'Validating project structure'

                sh '''
                    set -e

                    test -f Jenkinsfile
                    test -f scripts/test.sh
                    test -f scripts/health-check.sh
                    test -f scripts/deploy.sh
                    test -f scripts/rollback.sh
                    test -f scripts/backup.sh
                    test -f tests/smoke-test.sh

                    chmod +x scripts/*.sh
                    chmod +x tests/*.sh

                    echo "Project structure validation PASSED"
                '''
            }
        }

        stage('Automated Tests') {
            steps {
                echo 'Running automated LMS tests'

                sh '''
                    export LMS_URL="http://172.31.8.158"

                    ./scripts/test.sh
                '''
            }
        }

        stage('Test LMS SSH Connection') {
            steps {
                echo 'Testing SSH connection to LMS'

                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_CREDENTIALS,
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USERNAME'
                )]) {

                    sh '''
                        chmod 600 "$SSH_KEY"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            -o BatchMode=yes \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "echo SSH connection successful; hostname; whoami"
                    '''
                }
            }
        }

        stage('Backup Current Deployment') {
            steps {
                echo 'Creating LMS backup'

                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_CREDENTIALS,
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USERNAME'
                )]) {

                    sh '''
                        chmod 600 "$SSH_KEY"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "mkdir -p /opt/lms/backups && \
                             tar -czf /opt/lms/backups/lms-backup-${BUILD_NUMBER}.tar.gz /opt/lms 2>/dev/null || true"

                        echo "Backup stage completed"
                    '''
                }
            }
        }

        stage('Copy Deployment Files') {
            steps {
                echo 'Copying deployment files to LMS'

                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_CREDENTIALS,
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USERNAME'
                )]) {

                    sh '''
                        chmod 600 "$SSH_KEY"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "mkdir -p /opt/lms"

                        scp -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            scripts/deploy.sh \
                            "$SSH_USERNAME@$LMS_HOST:/opt/lms/deploy.sh"

                        scp -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            scripts/rollback.sh \
                            "$SSH_USERNAME@$LMS_HOST:/opt/lms/rollback.sh"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "chmod +x /opt/lms/deploy.sh /opt/lms/rollback.sh"

                        echo "Deployment files copied successfully"
                    '''
                }
            }
        }

        stage('Deploy LMS') {
            steps {
                echo 'Deploying LMS'

                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_CREDENTIALS,
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USERNAME'
                )]) {

                    sh '''
                        chmod 600 "$SSH_KEY"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "BUILD_NUMBER=${BUILD_NUMBER} APP_DIR=/opt/lms /opt/lms/deploy.sh"
                    '''
                }
            }
        }

        stage('Deployment Health Check') {
            steps {
                echo 'Checking LMS health'

                sh '''
                    export LMS_URL="http://172.31.8.158"

                    ./scripts/health-check.sh
                '''
            }
        }

        stage('Final Verification') {
            steps {
                echo 'Performing final LMS verification'

                withCredentials([sshUserPrivateKey(
                    credentialsId: env.SSH_CREDENTIALS,
                    keyFileVariable: 'SSH_KEY',
                    usernameVariable: 'SSH_USERNAME'
                )]) {

                    sh '''
                        chmod 600 "$SSH_KEY"

                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USERNAME@$LMS_HOST" \
                            "echo LMS hostname: \$(hostname); \
                             echo Docker containers:; \
                             docker ps --format 'table {{.Names}}\\t{{.Status}}'"
                    '''
                }
            }
        }
    }

    post {

        success {
            echo '======================================'
            echo 'LMS DEPLOYMENT SUCCESSFUL'
            echo '======================================'
        }

        failure {
            echo '======================================'
            echo 'LMS DEPLOYMENT FAILED'
            echo '======================================'

            echo 'Rollback stage would be executed here.'
        }

        always {
            echo '======================================'
            echo 'Pipeline execution completed'
            echo '======================================'
        }
    }
}