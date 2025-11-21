#!/bin/bash

# 1. Root User Check
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Switching to root..."
    sudo -i "$0" "$@"
    exit
fi

echo "=========================================="
echo " AWS EC2 Linux Initialization Script"
echo "=========================================="

# 2. Install Dependencies
echo "[1/6] Installing Dependencies..."
if command -v yum &>/dev/null; then
    yum update -y
    yum install -y git cronie jq
else
    echo "Error: This script supports 'yum' package manager (Amazon Linux, RHEL, CentOS)."
    exit 1
fi

# 3. Set Timezone
echo "[2/6] Setting Timezone to Asia/Seoul..."
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Seoul /etc/localtime
echo 'ZONE="Asia/Seoul"
UTC=true' > /etc/sysconfig/clock

systemctl enable crond
systemctl start crond

# 4. Install Docker & Docker Compose
echo "[3/6] Installing Docker & Docker Compose..."
yum install -y docker
usermod -aG docker ec2-user
service docker start
systemctl enable docker

# Install Docker Compose Plugin
mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Alias for docker-compose
echo "alias docker-compose='docker compose --compatibility \"\$@\"'" >> /etc/profile.d/docker-compose.sh
source /etc/profile.d/docker-compose.sh


# 5. AWS Configuration
echo "[4/6] Configuring AWS CLI..."
if [ -f ~/.aws/credentials ]; then
    echo "AWS CLI is already configured. Skipping configuration..."
    # Load existing credentials and region
    AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
    AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
    AWS_REGION=$(aws configure get region)
    AWS_REGION=${AWS_REGION:-ap-northeast-2}
    
    # Debug output (will be visible during script execution)
    echo "Loaded AWS Access Key ID: ${AWS_ACCESS_KEY_ID:0:10}..." # Show first 10 chars only
    echo "Loaded AWS Region: $AWS_REGION"
    
    # Verify credentials were loaded
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Warning: Could not load credentials from AWS CLI config."
        echo "Please ensure AWS CLI is properly configured."
    fi
else
    read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID < /dev/tty
    read -s -p "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY < /dev/tty
    echo ""
    read -p "Enter AWS Region [ap-northeast-2]: " AWS_REGION < /dev/tty
    AWS_REGION=${AWS_REGION:-ap-northeast-2}

    # Configure AWS CLI for root
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set region "$AWS_REGION"

    # Configure AWS CLI for ec2-user as well (optional but good for convenience)
    sudo -u ec2-user aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    sudo -u ec2-user aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    sudo -u ec2-user aws configure set region "$AWS_REGION"
fi

# 6. Route53 Configuration
echo "[5/6] Configuring Route53..."
read -p "Enter Domain Name for Route53 (e.g., example.com): " DOMAIN_NAME < /dev/tty
read -p "Enter Hosted Zone ID for $DOMAIN_NAME: " HOSTED_ZONE_ID < /dev/tty

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Error: Hosted Zone ID is required."
    echo "You may need to configure it manually later."
else
    echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"
fi

# 7. Generate Helper Scripts
echo "[6/6] Generating Helper Scripts..."

# auto-update-route53.sh
cat <<EOF > /bin/auto-update-route53.sh
#!/bin/bash

# Check params
if [ "\$#" -ne 4 ]; then
  echo "***ERROR: Missing parameters. Usage: \$0 <AccessKey> <SecretKey> <HostedZoneID> <Domain>"
  exit 1
fi

AWS_ACCESS_KEY_ID=\$1
AWS_SECRET_ACCESS_KEY=\$2
HOSTED_ZONE_ID=\$3
DOMAIN=\$4
REGION=$AWS_REGION

# Configure AWS for this session
export AWS_ACCESS_KEY_ID=\$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=\$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=\$REGION

# Define JSON payload
UPDATE_REQUEST='
{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "__domain__",
          "Type": "A",
          "TTL": 600,
          "ResourceRecords": [
            {
              "Value": "__ip__"
            }
          ]
        }
      }
    ]
  }
'

# Get IP
# Try multiple services for reliability
CURRENT_IP=\$(curl -s http://checkip.amazonaws.com || curl -s http://ifconfig.me)

if [ -z "\$CURRENT_IP" ]; then
    echo "Error: Could not determine Public IP."
    exit 1
fi

# Store last IP to avoid unnecessary API calls
LAST_IP_FILE="/tmp/ipupdate-lastip.txt"
if [ -f "\$LAST_IP_FILE" ]; then
    PREVIOUS_IP=\$(cat "\$LAST_IP_FILE")
else
    PREVIOUS_IP=""
fi

echo "Current IP: \$CURRENT_IP"
echo "Previous IP: \$PREVIOUS_IP"

if [ "\$CURRENT_IP" == "\$PREVIOUS_IP" ]; then
  echo "IP has not changed. No update needed."
else
  echo "IP changed. Updating Route53..."
  
  # Prepare JSON
  JSON_FILE="/tmp/ipupdate-request.json"
  echo "\$UPDATE_REQUEST" | sed "s/__domain__/\$DOMAIN/" | sed "s/__ip__/\$CURRENT_IP/" > "\$JSON_FILE"
  
  # Update Route53
  aws route53 change-resource-record-sets \\
        --hosted-zone-id "\$HOSTED_ZONE_ID" \\
        --change-batch file://"\$JSON_FILE"
        
  if [ \$? -eq 0 ]; then
      echo "\$CURRENT_IP" > "\$LAST_IP_FILE"
      echo "Route53 updated successfully."
  else
      echo "Failed to update Route53."
  fi
fi
EOF

chmod +x /bin/auto-update-route53.sh

# aws-service-boot.sh
echo "Generating aws-service-boot.sh with credentials..."
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "  HOSTED_ZONE_ID: $HOSTED_ZONE_ID"
echo "  DOMAIN: $DOMAIN_NAME"

cat <<EOF > /bin/aws-service-boot.sh
#!/bin/bash
# Wrapper script to call auto-update-route53.sh with configured credentials

AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
HOSTED_ZONE_ID="$HOSTED_ZONE_ID"
DOMAIN="$DOMAIN_NAME"

/bin/auto-update-route53.sh "\$AWS_ACCESS_KEY_ID" "\$AWS_SECRET_ACCESS_KEY" "\$HOSTED_ZONE_ID" "\$DOMAIN"
EOF

chmod +x /bin/aws-service-boot.sh

echo "=========================================="
echo " Initialization Complete!"
echo "=========================================="
echo "1. Docker and Docker Compose are installed."
echo "2. Timezone is set to Asia/Seoul."
echo "3. AWS CLI is configured."
echo "4. Helper scripts created in /bin/:"
echo "   - auto-update-route53.sh"
echo "   - aws-service-boot.sh"
echo ""
echo "To update Route53 manually, run:"
echo "  /bin/aws-service-boot.sh"
echo ""
echo "You can add this to User Data or crontab for auto-updates."
echo "=========================================="
