output "private_key_pem" {
  value = tls_private_key.key.private_key_pem
  sensitive = true
}

output "public_key_pem" {
  value = tls_private_key.key.public_key_pem
}

output "public_ip" {
  value = aws_instance.flask.public_ip
}