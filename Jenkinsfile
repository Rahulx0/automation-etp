pipeline {
  agent any

  options {
    timestamps()
  }

  environment {
    // --- Update these for your AWS setup ---
    AWS_DEFAULT_REGION = 'us-east-1'
    AWS_INSTANCE_TYPE  = 't3.micro'
    AWS_SUBNET_ID      = 'subnet-REPLACE'
    AWS_SECURITY_GROUP = '' // optional override; if empty we create one via Terraform
    AWS_KEY_PAIR       = 'REPLACE-keypair'
    GRAFANA_SSH_USER   = 'ubuntu'
    SSH_CIDR           = '0.0.0.0/0'
    GRAFANA_CIDR       = '0.0.0.0/0'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        withCredentials([
          string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
            set -euxo pipefail
            terraform -chdir=terraform init -input=false
            terraform -chdir=terraform apply -auto-approve -input=false \
              -var "region=$AWS_DEFAULT_REGION" \
              -var "subnet_id=$AWS_SUBNET_ID" \
              -var "key_name=$AWS_KEY_PAIR" \
              -var "instance_type=$AWS_INSTANCE_TYPE" \
              -var "ingress_cidr_ssh=$SSH_CIDR" \
              -var "ingress_cidr_grafana=$GRAFANA_CIDR" \
              $( [ -n "$AWS_SECURITY_GROUP" ] && echo -var "existing_sg_id=$AWS_SECURITY_GROUP" )

            terraform -chdir=terraform output -raw instance_id > ec2_instance_id.txt
            terraform -chdir=terraform output -raw public_ip > ec2_public_ip.txt
            echo "Terraform created $(cat ec2_instance_id.txt) at $(cat ec2_public_ip.txt)"
          '''
        }
      }
    }

    stage('Run Ansible') {
      steps {
        withCredentials([
          string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
          sshUserPrivateKey(credentialsId: 'grafana-ssh-key', keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')
        ]) {
          sh '''
            set -euxo pipefail
            PUBLIC_IP=$(cat ec2_public_ip.txt)

            cat > inventory.ini <<EOF
            [grafana]
            $PUBLIC_IP ansible_user=${SSH_USER:-$GRAFANA_SSH_USER} ansible_ssh_private_key_file=$SSH_KEY_FILE
            EOF

            ansible-playbook -i inventory.ini ansible/playbook.yml
          '''
        }
      }
    }
  }

  post {
    always {
      withCredentials([
        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
      ]) {
        sh '''
          set -euxo pipefail
          terraform -chdir=terraform destroy -auto-approve -input=false || true
        '''
      }
    }
  }
}
