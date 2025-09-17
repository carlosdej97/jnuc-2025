#!/bin/bash

echo "🎯 File Uploader Example"
echo "========================"
echo ""

# Check if the uploader is built
if [ ! -f ".build/release/FileUploader" ]; then
    echo "❌ FileUploader not found. Building first..."
    ./build.sh
    echo ""
fi

# Create a test file if it doesn't exist
TEST_FILE="test_upload.txt"
if [ ! -f "$TEST_FILE" ]; then
    echo "📝 Creating test file: $TEST_FILE"
    cat > "$TEST_FILE" << EOF
Hello from File Uploader!

This is a test file created by the example script.
It demonstrates the file upload functionality.

Timestamp: $(date)
File size: Small test file
Content-Type: text/plain

Features demonstrated:
- ✅ MIME type detection
- ✅ Authentication with shared secret
- ✅ Presigned URL generation
- ✅ Direct S3 upload
- ✅ Upload confirmation

End of test file.
EOF
    echo "✅ Test file created"
    echo ""
fi

echo "📊 Test file info:"
ls -lh "$TEST_FILE"
echo "🏷️  MIME type will be detected as: text/plain"
echo ""

echo "🚀 Starting upload..."
echo "====================>"
echo ""

# Run the uploader
.build/release/FileUploader "$TEST_FILE"

echo ""
echo "🏁 Example complete!"
echo ""
echo "💡 Try uploading your own files:"
echo "   .build/release/FileUploader /path/to/your/file.jpg"
echo "   .build/release/FileUploader --verbose ~/Documents/document.pdf"