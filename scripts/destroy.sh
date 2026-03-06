#!/bin/bash
# Safely destroy all Game Day infrastructure
# Run this when you're done practicing to avoid AWS charges
set -e

echo "================================================"
echo "  AWS Terraform Game Day -- Resource Cleanup"
echo "================================================"
echo ""

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    echo "No Terraform state found in current directory."
    echo "Make sure you're in the aws-terraform-gameday directory."
    exit 1
fi

# Show what will be destroyed
echo "Resources that will be destroyed:"
terraform state list 2>/dev/null || true
echo ""

# Confirm
read -p "Destroy all resources? This cannot be undone. (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "================================================"
echo "  All resources destroyed."
echo "  Verify in the AWS Console to be sure:"
echo "  https://console.aws.amazon.com/ec2/"
echo "================================================"
