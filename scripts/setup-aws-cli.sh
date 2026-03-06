#!/bin/bash
# AWS CLI Installation Script for Ubuntu/Debian
set -e

echo "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
cd /tmp && unzip -q -o awscliv2.zip
sudo ./aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

echo ""
echo "AWS CLI installed successfully:"
aws --version
echo ""
echo "Next step: Run 'aws configure' to set up your credentials."
echo "  Access Key ID:     <from IAM console>"
echo "  Secret Access Key: <from IAM console>"
echo "  Default region:    us-east-2"
echo "  Output format:     json"
