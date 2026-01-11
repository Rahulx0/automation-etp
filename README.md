# Jenkins + Ansible: EC2 Grafana

## What this repo has
- Jenkinsfile pipeline that provisions an EC2 instance via Terraform, installs Grafana with Ansible, and always destroys the instance after the run.
- Terraform module that creates (or reuses) SG + EC2 for Grafana.
- Ansible playbook to install Grafana on Ubuntu.

## What you must set up in Jenkins
1) Plugins/tools: Git plugin, Pipeline, GitHub, Ansible and awscli available on the agent, `jq` installed.
2) Credentials (create these IDs in Jenkins):
   - `aws-access-key-id` (Secret text): AWS access key ID.
   - `aws-secret-access-key` (Secret text): AWS secret access key.
   - `grafana-ssh-key` (SSH Username with private key): matches the AWS key pair; username typically `ubuntu` for Ubuntu AMIs.
3) Terraform variables: copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and fill `region`, `subnet_id`, `key_name`, CIDRs, and optionally `existing_sg_id`. Pipeline only runs `terraform apply/destroy -var-file=terraform.tfvars`.
4) Webhook trigger: enable “GitHub hook trigger for GITScm polling”.

## Ngrok + GitHub webhook quick steps
- Run Jenkins locally on 8080. Start Ngrok: `ngrok http 8080`.
- Copy the Ngrok https URL. In GitHub → Settings → Webhooks: URL `https://<ngrok-id>.ngrok.io/github-webhook/`, content type `application/json`, event: push.
- In Jenkins: Manage Jenkins → GitHub Servers → add server using the same URL; allow Jenkins to manage hooks.

## Pipeline flow
1) Checkout
2) Provision EC2 via Terraform using the provided subnet and key pair (creates SG unless you supply `AWS_SECURITY_GROUP`). Captures public IP.
3) Run Ansible against that IP to install Grafana.
4) Always destroys the stack in `post { always { ... } }`.

## Run locally for smoke (optional)
```
ansible-playbook -i "<public-ip>," --user ubuntu --private-key /path/to/key.pem ansible/playbook.yml
```

## Files
- Jenkinsfile
- ansible/playbook.yml
- ansible/ansible.cfg
