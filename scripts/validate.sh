#!/bin/bash
# Pre-flight checks before deploying
set -e

echo "Running pre-flight checks..."
echo ""

# Check AWS CLI
echo -n "AWS CLI:        "
if command -v aws &>/dev/null; then
    echo "$(aws --version 2>&1 | head -1)"
else
    echo "NOT INSTALLED -- run scripts/setup-aws-cli.sh"
    exit 1
fi

# Check Terraform
echo -n "Terraform:      "
if command -v terraform &>/dev/null; then
    terraform version -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1
else
    echo "NOT INSTALLED -- run scripts/setup-terraform.sh"
    exit 1
fi

# Check AWS credentials
echo -n "AWS Identity:   "
if aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null; then
    true
else
    echo "NOT CONFIGURED -- run 'aws configure'"
    exit 1
fi

# Check AWS region
echo -n "AWS Region:     "
aws configure get region 2>/dev/null || echo "not set (will use terraform.tfvars)"

# Check terraform files
echo -n "Terraform init: "
if [ -d ".terraform" ]; then
    echo "initialized"
else
    echo "not initialized -- run 'terraform init'"
fi

echo ""

# Validate terraform
echo -n "Syntax check:   "
if terraform validate -no-color 2>/dev/null | grep -q "Success"; then
    echo "passed"
else
    echo "FAILED"
    terraform validate
    exit 1
fi

echo ""
echo "All checks passed. Ready to deploy."
echo "Run: terraform plan"
