provider "aws" {
  region = var.aws_region
}

resource "aws_connect_instance" "teamA_connect" {
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  instance_alias           = var.instance_alias
}

resource "aws_connect_instance_storage_config" "instance_storage_teamA" {
  instance_id        = aws_connect_instance.teamA_connect.id
  resource_type      = "CALL_RECORDINGS"
  storage_type       = "S3"
  s3_bucket_arn      = var.s3_bucket_arn
  s3_bucket_prefix   = var.s3_bucket_prefix
  s3_encryption_key  = var.s3_encryption_key

  depends_on = [
    aws_connect_instance.teamA_connect
  ]
}

resource "aws_connect_phone_number" "instance_storage_teamA" {
  instance_id      = aws_connect_instance.teamA_connect.id
  phone_number     = var.phone_number
  phone_number_type = var.phone_number_type
  target_arn       = aws_connect_instance.teamA_connect.arn

  depends_on = [
    aws_connect_instance.teamA_connect
  ]
}

output "connect_instance_id" {
  value = aws_connect_instance.teamA_connect.id
}

output "connect_instance_arn" {
  value = aws_connect_instance.teamA_connect.arn
}

output "phone_number" {
  value = aws_connect_phone_number.instance_storage_teamA.phone_number
}
