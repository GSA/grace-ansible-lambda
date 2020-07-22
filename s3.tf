#tfsec:ignore:AWS002
resource "aws_s3_bucket" "bucket" {
  bucket        = local.app_name
  acl           = "private"
  force_destroy = true
  region        = var.region

  versioning {
    enabled = true
  }

  # TODO: Add this block/support for access logging
  # should be dynamic based on user requirement
  #
  #logging {
  #  target_bucket = "grace-${var.env}-access-logs"
  #  target_prefix = "${local.name}-logs/"
  #}

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.kms.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: If you change the settings for user_data then update the lambda.tf
# reference to USER_DATA_BUCKET and USER_DATA_KEY to reflect the change
resource "aws_s3_bucket_object" "user_data" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
  key    = "files/run.sh"
  content = templatefile("${path.module}/files/run.sh", {
    region     = var.region
    role       = aws_iam_role.role.name
    bucket     = aws_s3_bucket.bucket.id
    function   = local.app_name
    hosts_file = join("/", ["ansible", var.appenv])
    site_file  = "ansible/site.yml"
    key_file   = var.key_file
    ec2_user   = var.ec2_user
  })
  kms_key_id = aws_kms_key.kms.arn
}

resource "aws_s3_bucket_object" "create_secrets" {
  bucket     = aws_s3_bucket.bucket.id
  acl        = "private"
  key        = "files/create_secrets.py"
  source     = "${path.module}/files/create_secrets.py"
  kms_key_id = aws_kms_key.kms.arn
}

resource "aws_s3_bucket_object" "aws_events_callback_plugin" {
  bucket     = aws_s3_bucket.bucket.id
  acl        = "private"
  key        = "files/aws_events.py"
  source     = "${path.module}/files/aws_events.py"
  kms_key_id = aws_kms_key.kms.arn
}

resource "aws_s3_bucket_object" "ansible_key" {
  bucket     = aws_s3_bucket.bucket.id
  acl        = "private"
  key        = "ansible/"
  source     = "/dev/null"
  kms_key_id = aws_kms_key.kms.arn
}

# Execute lambda when ansible contents change
resource "aws_s3_bucket_notification" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.job_trigger_file
  }
}