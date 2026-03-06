#!/bin/bash
# Terraform Installation Script for Ubuntu/Debian
set -e

echo "Adding HashiCorp repository..."
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

echo "Installing Terraform..."
sudo apt-get update -qq
sudo apt-get install -y -qq terraform

echo ""
echo "Terraform installed successfully:"
terraform version
echo ""
echo "Next steps:"
echo "  1. cd aws-terraform-gameday"
echo "  2. terraform init"
echo "  3. terraform validate"
echo "  4. terraform plan"
echo "  5. terraform apply"
