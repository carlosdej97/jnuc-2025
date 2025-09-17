variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project, used as prefix for resource names"
  type        = string
  default     = "file-upload-api"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  type        = string
  # Note: S3 bucket names must be globally unique
  # You should override this in terraform.tfvars
}

variable "api_shared_secret" {
  description = "Shared secret for API authentication"
  type        = string
  sensitive   = true
  # This should be set in terraform.tfvars or via environment variable
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}