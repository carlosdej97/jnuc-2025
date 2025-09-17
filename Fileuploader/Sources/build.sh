#!/bin/bash

set -e

echo "🏗️  Building File Uploader..."
echo "================================"

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed or not in PATH"
    echo "Please install Xcode or Swift toolchain"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build

# Build in release mode
echo "🔨 Building application..."
swift build -c release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Show the location of the executable
    EXECUTABLE_PATH=".build/release/FileUploader"
    echo "📍 Executable location: $EXECUTABLE_PATH"
    echo "📍 Copying to /Users/Shared/FileUploader"
    cp "$EXECUTABLE_PATH" /Users/Shared/FileUploader
    
    # Ask if user wants to install system-wide
    echo ""
    read -p "Install to /usr/local/bin for system-wide access? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Installing to /usr/local/bin..."
        sudo cp "$EXECUTABLE_PATH" /usr/local/bin/file-uploader
        sudo chmod +x /usr/local/bin/file-uploader
        echo "✅ Installed as 'file-uploader' command"
        echo ""
        echo "You can now use: file-uploader /path/to/file"
    else
        echo "💡 To run: $EXECUTABLE_PATH /path/to/file"
    fi
    
    echo ""
    echo "🎉 Build complete!"
    
else
    echo "❌ Build failed!"
    exit 1
fi