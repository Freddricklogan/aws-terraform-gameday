# Environment Setup Guide

## Step 1: Linux Virtual Machine

You already have Parallels with Ubuntu installed. Ensure it's running and you can open a terminal.

If starting fresh:
- **Apple Silicon (M-series)**: Use Parallels Desktop (paid, required for ARM Macs)
- **Intel (x86)**: Use Oracle VirtualBox (free) + Vagrant from HashiCorp

## Step 2: Install AWS CLI

```bash
# Download and install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html

## Step 3: Create AWS Account

1. Go to https://aws.amazon.com and click "Create an AWS Account"
2. Enter email, password, and account name
3. Add a payment method (credit card required, free tier covers most usage)
4. Complete identity verification

### Set a Billing Budget (Critical)

1. Log into AWS Console as root user
2. Go to **Billing and Cost Management** (under your account name, top right)
3. Click **Budgets** in the left sidebar
4. Create a budget: **$20/month** recommended
5. Set up email alerts at 80% and 100% thresholds

This protects you from unexpected charges if you forget to destroy resources.

## Step 4: Create IAM User

The root account cannot launch resources directly. Create a worker account:

1. Go to **IAM Console** (search "IAM" in the AWS search bar)
2. Click **Users** > **Create user**
3. Username: `terraform-worker` (or your preference)
4. Check "Provide user access to the AWS Management Console"
5. Set a password
6. Click **Next**
7. **Attach policies directly**: Search and check these policies:
   - `AmazonEC2FullAccess`
   - `AmazonVPCFullAccess`
   - `ElasticLoadBalancingFullAccess`
   - `AutoScalingFullAccess`
   - `AmazonS3FullAccess` (for future modules)
   - `AmazonDynamoDBFullAccess` (for future modules)
8. Click **Create user**
9. Save the console sign-in URL

### Create Access Keys (for CLI/Terraform)

1. Go to **IAM** > **Users** > click your new user
2. Click **Security credentials** tab
3. Under **Access keys**, click **Create access key**
4. Select "Command Line Interface (CLI)"
5. Click **Create access key**
6. **SAVE BOTH KEYS** -- you cannot retrieve the secret key again:
   - Access Key ID: `AKIA...`
   - Secret Access Key: `wJal...`

## Step 5: Configure AWS CLI

```bash
aws configure
```

You will be prompted for:
```
AWS Access Key ID: <your-access-key>
AWS Secret Access Key: <your-secret-key>
Default region name: us-east-2
Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

This should return your account ID and user ARN.

## Step 6: Install Terraform

```bash
# Add HashiCorp GPG key and repo
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform version
```

## Step 7: VS Code Extensions

Install these VS Code extensions:
1. **HashiCorp HCL** -- syntax highlighting for .tf files
2. **HashiCorp Terraform** -- autocomplete, hover docs, formatting

## Step 8: Deploy and Verify

```bash
cd aws-terraform-gameday
terraform init
terraform validate
terraform plan
terraform apply    # Type 'yes'
```

After deployment, visit the load balancer URL shown in the output. You should see the "Infrastructure Deployed" welcome page.

**Always destroy when done:**
```bash
terraform destroy  # Type 'yes'
```
