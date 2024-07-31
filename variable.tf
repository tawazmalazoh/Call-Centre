variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "us-west-2"
}

variable "instance_alias" {
  description = "Alias for the Amazon Connect instance"
  type        = string
  default     = "team-A"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for call recordings"
  type        = string
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 bucket"
  type        = string
  default     = "connect-recordings"
}

variable "s3_encryption_key" {
  description = "ARN of the KMS key for S3 bucket encryption"
  type        = string
  default     = ""
}

variable "phone_number" {
  description = "Phone number to claim for Amazon Connect"
  type        = string
}

variable "phone_number_type" {
  description = "Type of phone number (TOLL_FREE or DID)"
  type        = string
  default     = "TOLL_FREE"
}
