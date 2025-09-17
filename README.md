# File Uploader

A Swift command-line application for uploading files to AWS S3 via API Gateway with presigned URLs.

## Features

- 📁 Automatic MIME type detection
- 🔐 Built-in authentication with shared secret
- 📤 Secure upload via presigned URLs
- ✅ Upload confirmation
- 🚀 Fast and efficient file transfers
- 📊 Progress and status reporting

## Requirements

- macOS 12.0 or later
- Swift 5.9 or later
- Xcode 14.0 or later (for development)

## Installation

### Method 1: Build from Source

1. Clone or download this directory
2. Navigate to the FileUploader directory
3. Build the application:

```bash
swift build -c release
```

4. The executable will be available at `.build/release/FileUploader`

### Method 2: Using the Build Script

```bash
chmod +x build.sh
./build.sh
```

This will build the application and copy it to `/usr/local/bin` for system-wide access.

## Usage

### Basic Usage

```bash
./FileUploader /path/to/your/file.jpg
```

### With Verbose Output

```bash
./FileUploader --verbose /path/to/your/file.pdf
```

### Help

```bash
./FileUploader --help
```

## Example

```bash
$ ./FileUploader ~/Documents/presentation.pdf

🚀 File Uploader v1.0.0
========================================
📁 File: presentation.pdf
📏 Size: 2048576 bytes
🏷️  MIME Type: application/pdf

🔗 Getting presigned URL...
✅ Presigned URL obtained
🗝️  File key: uploads/20241215_143022_a7b8c9d1_presentation.pdf

📤 Uploading file to S3...
✅ File uploaded successfully

✅ Confirming upload...
✅ Upload confirmed!

🎉 Upload completed successfully!
📍 S3 URL: https://your-unique-bucket-name-here-12345-panda-california.s3.amazonaws.com/uploads/20241215_143022_a7b8c9d1_presentation.pdf
🗄️  Bucket: your-unique-bucket-name-here-12345-panda-california
📏 Final size: 2048576 bytes
📅 Uploaded at: 2024-12-15T14:30:25.000Z
✅ Confirmed at: 2024-12-15T14:30:26.123456Z
```

## Configuration

The application is compiled with the following configuration:

- **API Base URL**: `https://c9z5nci28d.execute-api.us-east-1.amazonaws.com/v1`
- **Shared Secret**: Built into the application (as specified in terraform.tfvars)

To change these values, modify the `Config` struct in `main.swift` and rebuild.

## Supported File Types

The application automatically detects MIME types for common file extensions:

- Images: `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`, etc.
- Documents: `.pdf`, `.doc`, `.docx`, `.txt`, `.rtf`, etc.
- Archives: `.zip`, `.tar`, `.gz`, `.7z`, etc.
- Media: `.mp4`, `.mov`, `.mp3`, `.wav`, etc.
- And many more...

Unknown file types default to `application/octet-stream`.

## File Size Limits

- Maximum file size: 10 GB
- Upload timeout: 5 minutes

## Error Handling

The application provides clear error messages for common issues:

- File not found
- File too large
- Network connectivity issues
- Authentication failures
- S3 upload failures

## Development

### Building for Development

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Code Structure

- `main.swift` - Main application code
- `Config` - Configuration constants
- `HTTPClient` - HTTP networking layer
- `FileUploadService` - Core upload logic
- `FileUploader` - Command-line interface

## API Endpoints

The application uses the following API endpoints:

1. `POST /presigned-url` - Get presigned URL for upload
2. `PUT <presigned-url>` - Upload file to S3
3. `POST /confirm-upload` - Confirm upload completion

## Security

- Authentication uses Bearer token in Authorization header
- Presigned URLs expire after 1 hour
- All communications use HTTPS
- Shared secret is compiled into the binary

## Troubleshooting

### Common Issues

**"File not found"**
- Check that the file path is correct
- Ensure you have read permissions for the file

**"File too large"**
- Maximum file size is 10 GB
- Consider compressing large files

**"Network Error"**
- Check internet connectivity
- Verify API Gateway is accessible

**"Authentication failed"**
- Ensure the shared secret matches the API configuration
- Rebuild if configuration has changed

### Debug Mode

Run with `--verbose` flag for detailed output and debugging information.

## License

This project is provided as-is for demonstration purposes.
