pipeline {
    agent any

    environment {
        LANG = 'en_US.UTF-8'
        LC_ALL = 'en_US.UTF-8'
        LANGUAGE = 'en_US.UTF-8'
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS = '-no-color'
        SSH_CRED_ID = 'privatekey' 
        AWS_CRED_ID = 'badf87b5-c81c-440d-87b5-1698b311dcdd'
        TF_DIR = 'terraform'
    }

    stages {
        stage('Terraform Initialization') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                    sh 'set -euxo pipefail'
                    sh 'ls -la ${TF_DIR}'
                    sh 'terraform -chdir=${TF_DIR} init -input=false'
                    sh '''
                        set -euxo pipefail
                        VAR_FILE="${BRANCH_NAME}.tfvars"
                        if [ ! -f "${TF_DIR}/${VAR_FILE}" ]; then
                          VAR_FILE="terraform.tfvars"
                        fi
                        echo "Using var file: ${VAR_FILE}"
                        cat "${TF_DIR}/${VAR_FILE}"
                    '''
                }
            }
        }
        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                    sh '''
                        set -euxo pipefail
                        VAR_FILE="${BRANCH_NAME}.tfvars"
                        if [ ! -f "${TF_DIR}/${VAR_FILE}" ]; then
                          VAR_FILE="terraform.tfvars"
                        fi
                        terraform -chdir=${TF_DIR} plan -input=false -var-file=${VAR_FILE}
                    '''
                }
            }
        }
        stage('Validate Apply') {
            when {
                beforeInput true
                branch 'dev'
            }
            input {
                message "Do you want to apply this plan?"
                ok "Apply"
            }
            steps {
                echo 'Apply Accepted'
            }
        }
        stage('Terraform Provisioning') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                    script {
                        sh '''
                            set -euxo pipefail
                            VAR_FILE="${BRANCH_NAME}.tfvars"
                            if [ ! -f "${TF_DIR}/${VAR_FILE}" ]; then
                              VAR_FILE="terraform.tfvars"
                            fi
                            terraform -chdir=${TF_DIR} apply -auto-approve -input=false -var-file=${VAR_FILE}
                        '''

                        // 1. Extract Public IP Address of the provisioned instance
                        env.INSTANCE_IP = sh(
                            script: 'terraform -chdir=${TF_DIR} output -raw instance_public_ip', 
                            returnStdout: true
                        ).trim()
                        
                        // 2. Extract Instance ID (for AWS CLI wait) 
                        env.INSTANCE_ID = sh(
                            script: 'terraform -chdir=${TF_DIR} output -raw instance_id', 
                            returnStdout: true
                        ).trim()

                        echo "Provisioned Instance IP: ${env.INSTANCE_IP}"
                        echo "Provisioned Instance ID: ${env.INSTANCE_ID}"
                        
                        // 3. Create a dynamic inventory file for Ansible 
                        sh '''
                            set -euxo pipefail
                            cat > dynamic_inventory.ini <<EOF
[grafana]
${INSTANCE_IP}
EOF
                        '''
                    }
                }
            }
        }

        stage('Wait for AWS Instance Status') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                    echo "Waiting for instance ${env.INSTANCE_ID} to pass AWS health checks..."
                    
                    // --- This is the simple, powerful AWS CLI command ---
                    // It polls AWS until status checks pass or it hits the default timeout (usually 15 minutes)
                    sh "aws ec2 wait instance-status-ok --instance-ids ${env.INSTANCE_ID} --region us-east-1"  
                    
                    echo 'AWS instance health checks passed. Proceeding to Ansible.'
                }
            }
        }
        stage('Validate Ansible') {
            when {
                beforeInput true
                branch 'dev'
            }
            input {
                message "Do you want to run Ansible?"
                ok "Run Ansible"
            }
            steps {
                echo 'Ansible approved'
            }
        }
        stage('Ansible Configuration and Testing') {
            steps {
                // Preload host key to avoid interactive verification
                sh '''
                    set -euxo pipefail
                    mkdir -p ~/.ssh
                    chmod 700 ~/.ssh
                    ssh-keyscan -H ${INSTANCE_IP} >> ~/.ssh/known_hosts
                '''
                withEnv(['ANSIBLE_HOST_KEY_CHECKING=False']) {
                    ansiblePlaybook(
                        playbook: 'ansible/playbook.yml',
                        inventory: 'dynamic_inventory.ini', 
                        credentialsId: SSH_CRED_ID, // Key is securely injected by the plugin here
                    )
                }
            }
        }
        stage('Validate Destroy') {
            input {
                message "Do you want to destroy??"
                ok "Destroy"
            }
            steps {
                echo 'Destroy Approved'
            }
        }
        stage('Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                    sh '''
                        set -euxo pipefail
                        VAR_FILE="${BRANCH_NAME}.tfvars"
                        if [ ! -f "${TF_DIR}/${VAR_FILE}" ]; then
                          VAR_FILE="terraform.tfvars"
                        fi
                        terraform -chdir=${TF_DIR} destroy -auto-approve -input=false -var-file=${VAR_FILE}
                    '''
                }
            }
        }
    }    
    post {
        always {
            sh 'rm -f dynamic_inventory.ini'
        }
        success {
            echo 'Success!'
        }
        // failure {
        //     sh "terraform destroy -auto-approve -var-file=${env.BRANCH_NAME}.tfvars || echo \"Cleanup failed, please check manually.\""
        // }
        aborted {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CRED_ID]]) {
                sh "terraform destroy -auto-approve -var-file=${env.BRANCH_NAME}.tfvars || echo \"Cleanup failed, please check manually.\""
            }
        }
    }
}
