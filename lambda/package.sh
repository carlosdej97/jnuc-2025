#!/bin/bash

# Script to package Lambda function for deployment
echo "Packaging Lambda function..."

# Remove existing zip file if it exists
rm -f function.zip

# Create the zip file with the Python code
zip function.zip index.py

echo "Lambda function packaged as function.zip"