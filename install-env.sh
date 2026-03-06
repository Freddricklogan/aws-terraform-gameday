#!/bin/bash
# Bootstrap script for EC2 instances
# This runs automatically on first boot via the launch template user_data

# Update package lists
sudo apt-get update -y

# Install nginx web server
sudo apt-get install -y nginx

# Get instance metadata for the welcome page
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "unknown")

# Create a custom welcome page
cat > /var/www/html/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Terraform Game Day</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0a23; color: #fff; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { text-align: center; max-width: 600px; padding: 40px; }
        h1 { font-size: 2.5rem; margin-bottom: 10px; color: #00d4ff; }
        h2 { font-size: 1.2rem; color: #8892b0; margin-bottom: 30px; font-weight: 400; }
        .info { background: rgba(255,255,255,0.05); border-radius: 12px; padding: 24px; margin: 20px 0; text-align: left; }
        .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255,255,255,0.1); }
        .info-row:last-child { border-bottom: none; }
        .label { color: #8892b0; }
        .value { color: #00d4ff; font-family: monospace; }
        .status { display: inline-block; background: #00c853; color: #000; padding: 6px 16px; border-radius: 20px; font-weight: 600; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Infrastructure Deployed</h1>
        <h2>AWS Terraform Game Day Preparation</h2>
        <div class="info">
            <div class="info-row"><span class="label">Instance ID</span><span class="value">${INSTANCE_ID}</span></div>
            <div class="info-row"><span class="label">Availability Zone</span><span class="value">${AZ}</span></div>
            <div class="info-row"><span class="label">Private IP</span><span class="value">${LOCAL_IP}</span></div>
            <div class="info-row"><span class="label">Web Server</span><span class="value">nginx</span></div>
        </div>
        <span class="status">HEALTHY</span>
    </div>
</body>
</html>
HTMLEOF

# Ensure nginx is running
sudo systemctl enable nginx
sudo systemctl restart nginx
