resource "aws_secretsmanager_secret" "secret_key" {
  name        = var.secret_name
  description = "Ansible ssh key pair secret key"
  kms_key_id  = aws_kms_key.kms.arn
  tags = {
    Name = "ansible-key-pairs"
  }
}

resource "aws_secretsmanager_secret_rotation" "secret_key" {
  secret_id           = aws_secretsmanager_secret.secret_key.id
  rotation_lambda_arn = aws_lambda_function.rotate_keypair.arn

  rotation_rules {
    automatically_after_days = 60
  }
}
