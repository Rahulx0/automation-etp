variable "region" {
  type        = string
  description = "AWS region"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to place the instance in"
}

variable "key_name" {
  type        = string
  description = "Existing AWS key pair name"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ingress_cidr_ssh" {
  type        = string
  description = "CIDR allowed for SSH"
  default     = "0.0.0.0/0"
}

variable "ingress_cidr_grafana" {
  type        = string
  description = "CIDR allowed for Grafana (3000/tcp)"
  default     = "0.0.0.0/0"
}

variable "existing_sg_id" {
  type        = string
  description = "Optional: use existing security group instead of creating one"
  default     = ""
}
