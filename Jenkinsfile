pipeline {

    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {

        // ==============================
        // LMS SERVER CONFIGURATION
        // ==============================

        LMS_HOST = '172.31.8.158'
        LMS_USER = 'ubuntu'

        // Change this to your actual LMS URL
        LMS_URL = 'http://local.openedx.io'

        // Jenkins credential ID
        SSH_CREDENTIALS = 'lms-ssh-key'

        // LMS deployment directory
        REMOTE_APP_DIR = '/opt/lms'

    }

    stages {

        // ==========================================
        // 1. CHECKOUT
        // ==========================================

        stage('Checkout') {

            steps {

                echo '======================================'
                echo 'Checking out LMS source code'
                echo '======================================'

                checkout scm

                sh '''
                    echo "Git commit:"
                    git rev-parse HEAD

                    echo "Git branch:"
                    git branch --show-current

                    echo "Repository files:"
                    ls -la
                '''
            }
        }


        // ==========================================
        // 2. VALIDATE PROJECT
        // ==========================================

        stage('Validate') {

            steps {

                echo '======================================'
                echo 'Validating project structure'
                echo '======================================'

                sh '''
                    set -e

                    test -f Jenkinsfile
                    test -f scripts/test.sh
                    test -f scripts/health-check.sh
                    test -f scripts/deploy.sh
                    test -f scripts/rollback.sh
                    test -f scripts/backup.sh
                    test -f tests/smoke-test.sh

                    echo "Project structure validation PASSED"
                '''
            }
        }


        // ==========================================
        // 3. AUTOMATED TESTING
        // ==========================================

        stage('Automated Tests') {

            steps {

                echo '======================================'
                echo 'Running automated LMS tests'
                echo '======================================'

                sh '''
                    set -e

                    chmod +x scripts/*.sh
                    chmod +x tests/*.sh

                    export LMS_URL="${LMS_URL}"

                    ./scripts/test.sh
                '''
            }
        }


        // ==========================================
        // 4. CREATE RELEASE ID
        // ==========================================

        stage('Create Release') {

            steps {

                script {

                    env.RELEASE_ID =
                        "${BUILD_NUMBER}-${GIT_COMMIT.take(8)}"
                }

                echo "Release ID: ${env.RELEASE_ID}"
            }
        }


        // ==========================================
        // 5. CHECK SSH CONNECTION
        // ==========================================

        stage('Test LMS SSH Connection') {

            steps {

                echo '======================================'
                echo 'Testing SSH connection to LMS'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        ssh \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'echo SSH connection successful && hostname && whoami'
                    """
                }
            }
        }


        // ==========================================
        // 6. BACKUP CURRENT LMS
        // ==========================================

        stage('Backup Current Deployment') {

            steps {

                echo '======================================'
                echo 'Creating LMS backup'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        ssh \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'if [ -f ${REMOTE_APP_DIR}/current/scripts/backup.sh ]; then
                            APP_DIR=${REMOTE_APP_DIR}
                            bash ${REMOTE_APP_DIR}/current/scripts/backup.sh
                        else
                            echo "Backup script not found - skipping backup"
                        fi'
                    """
                }
            }
        }


        // ==========================================
        // 7. CREATE REMOTE RELEASE DIRECTORY
        // ==========================================

        stage('Prepare Deployment') {

            steps {

                echo '======================================'
                echo 'Preparing LMS deployment'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        ssh \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'mkdir -p ${REMOTE_APP_DIR}/releases/${RELEASE_ID}'
                    """
                }
            }
        }


        // ==========================================
        // 8. COPY PROJECT TO LMS
        // ==========================================

        stage('Copy Deployment Files') {

            steps {

                echo '======================================'
                echo 'Copying deployment files to LMS'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        tar czf - . | \
                        ssh \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'tar xzf - -C ${REMOTE_APP_DIR}/releases/${RELEASE_ID}'
                    """
                }
            }
        }


        // ==========================================
        // 9. DEPLOY LMS
        // ==========================================

        stage('Deploy LMS') {

            steps {

                echo '======================================'
                echo 'Deploying LMS'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        ssh \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'cd ${REMOTE_APP_DIR}/releases/${RELEASE_ID} && \
                         APP_DIR=${REMOTE_APP_DIR} \
                         BUILD_NUMBER=${RELEASE_ID} \
                         bash scripts/deploy.sh'
                    """
                }
            }
        }


        // ==========================================
        // 10. HEALTH CHECK
        // ==========================================

        stage('Deployment Health Check') {

            steps {

                echo '======================================'
                echo 'Checking LMS deployment health'
                echo '======================================'

                timeout(time: 10, unit: 'MINUTES') {

                    sshagent(credentials: [env.SSH_CREDENTIALS]) {

                        sh """
                            ssh \
                            -o StrictHostKeyChecking=no \
                            ${LMS_USER}@${LMS_HOST} \
                            'LMS_URL="${LMS_URL}" \
                             APP_DIR="${REMOTE_APP_DIR}" \
                             bash ${REMOTE_APP_DIR}/current/scripts/health-check.sh'
                        """
                    }
                }
            }
        }


        // ==========================================
        // 11. FINAL VERIFICATION
        // ==========================================

        stage('Final Verification') {

            steps {

                echo '======================================'
                echo 'Final LMS verification'
                echo '======================================'

                sshagent(credentials: [env.SSH_CREDENTIALS]) {

                    sh """
                        ssh \
                        -o StrictHostKeyChecking=no \
                        ${LMS_USER}@${LMS_HOST} \
                        'echo "Current release:" && \
                         readlink -f ${REMOTE_APP_DIR}/current && \
                         echo "Docker containers:" && \
                         docker ps'
                    """
                }
            }
        }
    }


    // ==============================================
    // POST PIPELINE ACTIONS
    // ==============================================

    post {

        // ==========================================
        // SUCCESS
        // ==========================================

        success {

            echo '======================================'
            echo 'LMS DEPLOYMENT SUCCESSFUL'
            echo '======================================'

            emailext(
                to: 'abybarath27@gmail.com',
                subject: "SUCCESS: LMS Deployment #${BUILD_NUMBER}",
                body: """
LMS Deployment Successful

Job:
${JOB_NAME}

Build:
#${BUILD_NUMBER}

Commit:
${GIT_COMMIT}

Release:
${RELEASE_ID}

LMS URL:
${LMS_URL}

Deployment health check:
PASSED

Application status:
HEALTHY

Build URL:
${BUILD_URL}
"""
            )
        }


        // ==========================================
        // FAILURE + ROLLBACK
        // ==========================================

        failure {

            echo '======================================'
            echo 'LMS DEPLOYMENT FAILED'
            echo '======================================'

            script {

                try {

                    echo 'Starting automatic rollback...'

                    sshagent(credentials: [env.SSH_CREDENTIALS]) {

                        sh """
                            ssh \
                            -o StrictHostKeyChecking=no \
                            ${LMS_USER}@${LMS_HOST} \
                            'if [ -f ${REMOTE_APP_DIR}/current/scripts/rollback.sh ]; then
                                APP_DIR=${REMOTE_APP_DIR}
                                bash ${REMOTE_APP_DIR}/current/scripts/rollback.sh
                            else
                                echo "Rollback script not found"
                                exit 1
                            fi'
                        """
                    }

                    echo 'Rollback completed'

                } catch (rollbackError) {

                    echo '======================================'
                    echo 'ROLLBACK FAILED'
                    echo '======================================'

                    echo "${rollbackError}"
                }
            }


            emailext(
                to: 'YOUR_EMAIL@example.com',
                subject: "FAILED: LMS Deployment #${BUILD_NUMBER}",
                body: """
LMS Deployment FAILED

Job:
${JOB_NAME}

Build:
#${BUILD_NUMBER}

Commit:
${GIT_COMMIT}

Release:
${RELEASE_ID}

Deployment or health check failed.

Automatic rollback was triggered.

Please review the Jenkins console output.

Build URL:
${BUILD_URL}
"""
            )
        }


        // ==========================================
        // ALWAYS
        // ==========================================

        always {

            echo '======================================'
            echo 'Pipeline execution completed'
            echo '======================================'
        }
    }
}
