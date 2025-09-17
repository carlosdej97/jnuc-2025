terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket for file uploads
resource "aws_s3_bucket" "file_upload_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = "File Upload Bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "file_upload_bucket_versioning" {
  bucket = aws_s3_bucket.file_upload_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "file_upload_bucket_encryption" {
  bucket = aws_s3_bucket.file_upload_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# AWS Secrets Manager secret for API authentication
resource "aws_secretsmanager_secret" "api_secret" {
  name        = "${var.project_name}-api-secret"
  description = "Shared secret for API authentication"

  tags = {
    Name        = "API Authentication Secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "api_secret_version" {
  secret_id = aws_secretsmanager_secret.api_secret.id
  secret_string = jsonencode({
    shared_secret = var.api_shared_secret
  })
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "Lambda Execution Role"
    Environment = var.environment
  }
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.api_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAttributes"
        ]
        Resource = "${aws_s3_bucket.file_upload_bucket.arn}/*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "file_upload_api" {
  filename         = "lambda/function.zip"
  function_name    = "${var.project_name}-file-upload-api"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30
  source_code_hash = filebase64sha256("lambda/function.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.file_upload_bucket.bucket
      SECRET_ARN  = aws_secretsmanager_secret.api_secret.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = {
    Name        = "File Upload API Lambda"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-file-upload-api"
  retention_in_days = 14

  tags = {
    Name        = "Lambda Logs"
    Environment = var.environment
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "file_upload_api" {
  name        = "${var.project_name}-file-upload-api"
  description = "API for secure file uploads with shared secret authentication"

  tags = {
    Name        = "File Upload API"
    Environment = var.environment
  }
}

# API Gateway Resource for presigned URL generation
resource "aws_api_gateway_resource" "presigned_url_resource" {
  rest_api_id = aws_api_gateway_rest_api.file_upload_api.id
  parent_id   = aws_api_gateway_rest_api.file_upload_api.root_resource_id
  path_part   = "presigned-url"
}

# API Gateway Method for presigned URL
resource "aws_api_gateway_method" "presigned_url_method" {
  rest_api_id   = aws_api_gateway_rest_api.file_upload_api.id
  resource_id   = aws_api_gateway_resource.presigned_url_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# API Gateway Integration for presigned URL
resource "aws_api_gateway_integration" "presigned_url_integration" {
  rest_api_id = aws_api_gateway_rest_api.file_upload_api.id
  resource_id = aws_api_gateway_resource.presigned_url_resource.id
  http_method = aws_api_gateway_method.presigned_url_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.file_upload_api.invoke_arn
}

# API Gateway Resource for upload confirmation
resource "aws_api_gateway_resource" "confirm_upload_resource" {
  rest_api_id = aws_api_gateway_rest_api.file_upload_api.id
  parent_id   = aws_api_gateway_rest_api.file_upload_api.root_resource_id
  path_part   = "confirm-upload"
}

# API Gateway Method for upload confirmation
resource "aws_api_gateway_method" "confirm_upload_method" {
  rest_api_id   = aws_api_gateway_rest_api.file_upload_api.id
  resource_id   = aws_api_gateway_resource.confirm_upload_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# API Gateway Integration for upload confirmation
resource "aws_api_gateway_integration" "confirm_upload_integration" {
  rest_api_id = aws_api_gateway_rest_api.file_upload_api.id
  resource_id = aws_api_gateway_resource.confirm_upload_resource.id
  http_method = aws_api_gateway_method.confirm_upload_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.file_upload_api.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.file_upload_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method.presigned_url_method,
    aws_api_gateway_integration.presigned_url_integration,
    aws_api_gateway_method.confirm_upload_method,
    aws_api_gateway_integration.confirm_upload_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.file_upload_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.presigned_url_resource.id,
      aws_api_gateway_method.presigned_url_method.id,
      aws_api_gateway_integration.presigned_url_integration.id,
      aws_api_gateway_resource.confirm_upload_resource.id,
      aws_api_gateway_method.confirm_upload_method.id,
      aws_api_gateway_integration.confirm_upload_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.file_upload_api.id
  stage_name    = var.api_stage_name

  tags = {
    Name        = "API Stage"
    Environment = var.environment
  }
}