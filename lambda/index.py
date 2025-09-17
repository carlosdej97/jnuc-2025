import json
import boto3
import uuid
import os
from datetime import datetime
from urllib.parse import unquote, quote

def authenticate_request(event, secret_arn):
    """
    Authenticate the request using shared secret from AWS Secrets Manager
    """
    # Check for Authorization header
    headers = event.get('headers', {})
    auth_header = headers.get('Authorization') or headers.get('authorization')
    
    if not auth_header:
        return False, {
            'statusCode': 401,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Missing Authorization header'
            })
        }
    
    # Extract the token from Authorization header (expects "Bearer <token>")
    if not auth_header.startswith('Bearer '):
        return False, {
            'statusCode': 401,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid Authorization header format. Expected: Bearer <token>'
            })
        }
    
    provided_token = auth_header[7:]  # Remove "Bearer " prefix
    
    # Retrieve the shared secret from AWS Secrets Manager
    secrets_client = boto3.client('secretsmanager')
    
    try:
        secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_data = json.loads(secret_response['SecretString'])
        expected_secret = secret_data.get('shared_secret')
        
        if not expected_secret:
            return False, {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Shared secret not found in Secrets Manager'
                })
            }
            
    except Exception as e:
        print(f"Error retrieving secret: {str(e)}")
        return False, {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Failed to retrieve authentication secret'
            })
        }
    
    # Validate the provided token against the shared secret
    if provided_token != expected_secret:
        return False, {
            'statusCode': 401,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid authentication token'
            })
        }
    
    return True, None

def generate_presigned_url(event, context):
    """
    Generate a presigned URL for direct S3 upload
    """
    bucket_name = os.environ.get('BUCKET_NAME')
    secret_arn = os.environ.get('SECRET_ARN')
    
    if not bucket_name or not secret_arn:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Missing required environment variables'
            })
        }
    
    # Authenticate the request
    authenticated, auth_error = authenticate_request(event, secret_arn)
    if not authenticated:
        return auth_error
    
    # Parse the request body
    body = event.get('body', '')
    if event.get('isBase64Encoded', False):
        import base64
        body = base64.b64decode(body).decode('utf-8')
    
    try:
        request_data = json.loads(body) if body else {}
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid JSON in request body'
            })
        }
    
    # Extract file metadata
    file_name = request_data.get('file_name')
    content_type = request_data.get('content_type', 'application/octet-stream')
    file_size = request_data.get('file_size')  # Optional, for validation
    
    if not file_name:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Missing required field: file_name'
            })
        }
    
    # Generate unique file key
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    unique_id = str(uuid.uuid4())[:8]
    file_key = f"uploads/{timestamp}_{unique_id}_{file_name}"
    
    # Generate presigned URL for PUT operation
    s3_client = boto3.client('s3')
    
    try:
        # Set conditions for the presigned URL
        conditions = [
            {'bucket': bucket_name},
            {'key': file_key},
            {'Content-Type': content_type}
        ]
        
        # Add metadata conditions
        # URL-encode the filename to ensure it contains only ASCII characters
        encoded_filename = quote(file_name, safe='')
        metadata = {
            'x-amz-meta-uploaded-at': datetime.now().isoformat(),
            'x-amz-meta-original-filename': encoded_filename
        }
        
        for key, value in metadata.items():
            conditions.append({key: value})
        
        # Optional: Add file size limit (max 10GB)
        max_file_size = 10 * 1024 * 1024 * 1024  # 10GB
        conditions.append(['content-length-range', 1, max_file_size])
        
        # Generate presigned POST URL (better for large files)
        presigned_post = s3_client.generate_presigned_post(
            Bucket=bucket_name,
            Key=file_key,
            Fields={
                'Content-Type': content_type,
                **metadata
            },
            Conditions=conditions,
            ExpiresIn=3600  # 1 hour expiration
        )
        
        # Also generate a simple presigned PUT URL as alternative
        presigned_put_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': file_key,
                'ContentType': content_type,
                'Metadata': {
                    'uploaded-at': datetime.now().isoformat(),
                    'original-filename': encoded_filename
                }
            },
            ExpiresIn=3600
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'presigned_post': {
                    'url': presigned_post['url'],
                    'fields': presigned_post['fields']
                },
                'presigned_put_url': presigned_put_url,
                'file_key': file_key,
                'bucket': bucket_name,
                'expires_in': 3600,
                'max_file_size': max_file_size,
                'generated_at': datetime.now().isoformat(),
                'instructions': {
                    'post_method': 'Use presigned_post.url with form data including presigned_post.fields',
                    'put_method': 'Use presigned_put_url with PUT request and file as body'
                }
            })
        }
        
    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Failed to generate presigned URL'
            })
        }

def confirm_upload(event, context):
    """
    Confirm that a file upload was completed successfully
    """
    bucket_name = os.environ.get('BUCKET_NAME')
    secret_arn = os.environ.get('SECRET_ARN')
    
    if not bucket_name or not secret_arn:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Missing required environment variables'
            })
        }
    
    # Authenticate the request
    authenticated, auth_error = authenticate_request(event, secret_arn)
    if not authenticated:
        return auth_error
    
    # Parse the request body
    body = event.get('body', '')
    if event.get('isBase64Encoded', False):
        import base64
        body = base64.b64decode(body).decode('utf-8')
    
    try:
        request_data = json.loads(body) if body else {}
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid JSON in request body'
            })
        }
    
    file_key = request_data.get('file_key')
    
    if not file_key:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Missing required field: file_key'
            })
        }
    
    # Check if the file exists in S3
    s3_client = boto3.client('s3')
    
    try:
        response = s3_client.head_object(Bucket=bucket_name, Key=file_key)
        
        # Generate the S3 object URL
        s3_url = f"https://{bucket_name}.s3.amazonaws.com/{file_key}"
        
        # Decode the original filename in metadata for display
        metadata = response.get('Metadata', {}).copy()
        if 'original-filename' in metadata:
            try:
                metadata['original-filename'] = unquote(metadata['original-filename'])
            except Exception:
                # If decoding fails, keep the encoded version
                pass
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'File upload confirmed',
                'file_key': file_key,
                's3_url': s3_url,
                'bucket': bucket_name,
                'file_size': response['ContentLength'],
                'content_type': response['ContentType'],
                'last_modified': response['LastModified'].isoformat(),
                'metadata': metadata,
                'confirmed_at': datetime.now().isoformat()
            })
        }
        
    except s3_client.exceptions.NoSuchKey:
        return {
            'statusCode': 404,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'File not found in S3'
            })
        }
    except Exception as e:
        print(f"Error confirming upload: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Failed to confirm upload'
            })
        }

def handler(event, context):
    """
    Main Lambda handler that routes requests to appropriate functions
    """
    try:
        # Get the resource path to determine which function to call
        resource_path = event.get('resource', '')
        http_method = event.get('httpMethod', '')
        
        print(f"Resource: {resource_path}, Method: {http_method}")
        
        if resource_path == '/presigned-url' and http_method == 'POST':
            return generate_presigned_url(event, context)
        elif resource_path == '/confirm-upload' and http_method == 'POST':
            return confirm_upload(event, context)
        else:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Endpoint not found',
                    'available_endpoints': [
                        'POST /presigned-url - Generate presigned URL for file upload',
                        'POST /confirm-upload - Confirm file upload completion'
                    ]
                })
            }
        
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error'
            })
        }
