output "api_gateway_url" {
  description = "The URL of the API Gateway endpoint"
  value       = "${aws_api_gateway_rest_api.file_upload_api.execution_arn}/${aws_api_gateway_stage.api_stage.stage_name}"
}

output "api_gateway_base_url" {
  description = "The base URL for the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.file_upload_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}"
}

output "presigned_url_endpoint" {
  description = "The endpoint for generating presigned URLs"
  value       = "https://${aws_api_gateway_rest_api.file_upload_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}/presigned-url"
}

output "confirm_upload_endpoint" {
  description = "The endpoint for confirming file uploads"
  value       = "https://${aws_api_gateway_rest_api.file_upload_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}/confirm-upload"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  value       = aws_s3_bucket.file_upload_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for file uploads"
  value       = aws_s3_bucket.file_upload_bucket.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.file_upload_api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.file_upload_api.arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.api_secret.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.api_secret.name
}