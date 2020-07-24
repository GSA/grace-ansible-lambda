output "role_arn" {
  value = aws_iam_role.role.arn
}
output "profile_arn" {
  value = aws_iam_instance_profile.profile.arn
}
output "kms_key_arn" {
  value = aws_kms_key.kms.arn
}
output "kms_key_alias" {
  value = aws_kms_alias.kms.name
}
output "s3_bucket" {
  value = aws_s3_bucket.bucket.id
}
output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}