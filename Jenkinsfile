pipeline {
    agent any

    environment {
        TARGET_SERVER = 'dso505@10.34.100.158'
        REPO_URL = 'https://github.com/rayhanegar/twitah-devsecops-secured.git'
        BRANCH = 'main'
        APP_PATH = '/home/dso505/twitah-devsecops-secured'
        SNS_PATH = '/home/dso505/sns-devsecops-secure'
    }

    triggers {
        pollSCM('H/15 * * * *')
    }

    stages {
        stage('Prepare') {
            steps {
                sh """
                    ssh -o StrictHostKeyChecking=no ${TARGET_SERVER} '
                        if [ -d ${APP_PATH} ]; then
                            cd ${APP_PATH} && git fetch origin && git reset --hard origin/${BRANCH}
                        else
                            git clone -b ${BRANCH} ${REPO_URL} ${APP_PATH}
                        fi
                        rm -f ${SNS_PATH}/src
                    '
                """
            }
        }

        stage('SAST Scan') {
            steps {
                script {
                    def scanResult = sh(
                        script: """
                            ssh -o StrictHostKeyChecking=no ${TARGET_SERVER} '
                                cd ${APP_PATH}/src
                                /home/dso505/.local/bin/semgrep scan --config p/owasp-top-ten --severity ERROR --error .
                            '
                        """,
                        returnStatus: true
                    )
                    
                    if (scanResult != 0) {
                        error('SAST scan detected security vulnerabilities')
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    ssh -o StrictHostKeyChecking=no ${TARGET_SERVER} '
                        ln -s ${APP_PATH}/src ${SNS_PATH}/src
                        cd ${SNS_PATH} && docker compose restart sns-dso-app web
                    '
                """
            }
        }

        stage('Verify') {
            steps {
                sh """
                    ssh -o StrictHostKeyChecking=no ${TARGET_SERVER} '
                        docker ps --filter name=sns-dso --format \"table {{.Names}}\t{{.Status}}\"
                        sleep 5
                        curl -sf http://sns-secure.devsec505.com > /dev/null || exit 1
                    '
                """
            }
        }
    }
}