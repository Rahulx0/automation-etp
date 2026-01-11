output "instance_id" {
  value       = aws_instance.grafana.id
  description = "Created instance ID"
}

output "public_ip" {
  value       = aws_instance.grafana.public_ip
  description = "Public IP for Grafana host"
}

output "instance_public_ip" {
  value       = aws_instance.grafana.public_ip
  description = "Public IP (alias for instance_public_ip)"
}
