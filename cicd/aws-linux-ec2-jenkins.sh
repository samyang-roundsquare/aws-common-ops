#!/bin/bash

echo "=========================================="
echo " AWS EC2 Jenkins CI/CD Setup Script"
echo "=========================================="

# 1. Check Root Privileges (Removed)
# This script should be run as a normal user (e.g., ec2-user) who has docker access.
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: You are running as root. It is recommended to run as a standard user (e.g., ec2-user)."
fi

# 2. Check Environment (Docker & Docker Compose)
echo "[1/4] Checking Environment..."

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please run aws-linux-ec2-init.sh first."
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "Warning: Docker is not running or current user cannot access docker."
    echo "Attempting to fix permissions..."
    
    # Try to add user to docker group
    if command -v sudo &> /dev/null; then
        sudo usermod -aG docker $USER
        sudo chmod 666 /var/run/docker.sock
        echo "Added $USER to docker group and updated socket permissions."
    else
        echo "Error: 'sudo' is not available. Cannot fix permissions automatically."
        exit 1
    fi
    
    # Retry check
    if ! docker info > /dev/null 2>&1; then
        echo "Error: Still cannot access Docker. You may need to log out and log back in."
        exit 1
    fi
    echo "Docker access verified."
fi

if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed or not compatible. Please run aws-linux-ec2-init.sh first."
    exit 1
fi

# AWS CLI 확인 (선택 사항이지만 권장)
if ! command -v aws &> /dev/null; then
    echo "Warning: AWS CLI is not installed."
fi

echo "Environment verification passed."

# 3. PEM 파일 탐색 및 생성 (현재 디렉토리)
echo "[2/4] Checking for PEM file..."
CURRENT_DIR=$(pwd)
FOUND_PEM=$(find "$CURRENT_DIR" -maxdepth 1 -name "*.pem" | head -n 1)

if [ -z "$FOUND_PEM" ]; then
    echo "No .pem file found in $CURRENT_DIR."
    echo "Do you want to generate a new SSH key for GitHub connection? (y/n)"
    read -r GENERATE_KEY < /dev/tty
    
    if [ "$GENERATE_KEY" = "y" ] || [ "$GENERATE_KEY" = "Y" ]; then
        echo "Enter your email address for the SSH key:"
        read -r EMAIL < /dev/tty
        
        if [ -z "$EMAIL" ]; then
            echo "Email is required. Skipping key generation."
        else
            echo "Generating SSH key (ed25519)..."
            ssh-keygen -t ed25519 -C "$EMAIL" -f "$CURRENT_DIR/key.pem" -N ""
            
            echo ""
            echo "=================================================================="
            echo "                       IMPORTANT: GitHub Setup                    "
            echo "=================================================================="
            echo "Please copy the following public key and add it to your GitHub repository:"
            echo "Settings > Deploy keys > Add deploy key"
            echo "------------------------------------------------------------------"
            cat "$CURRENT_DIR/key.pem.pub"
            echo "------------------------------------------------------------------"
            echo "=================================================================="
            echo "Press ENTER after you have registered the key on GitHub to continue..."
            read -r WAIT_CONFIRM < /dev/tty
            
            FOUND_PEM="$CURRENT_DIR/key.pem"
        fi
    else
        echo "Skipping key generation. Jenkins might not be able to access GitHub."
    fi
fi

PEM_FILENAME=""
if [ -n "$FOUND_PEM" ]; then
    echo "Found PEM file: $FOUND_PEM"
    # PEM 파일 경로를 변수에 저장
    PEM_PATH="$FOUND_PEM"
else
    echo "Warning: No .pem file found in $CURRENT_DIR."
    echo "Jenkins might not be able to access other servers."
    PEM_PATH=""
fi

# 4. Download CI/CD Files
echo "[3/4] Downloading CI/CD Configuration Files..."
BASE_URL="https://raw.githubusercontent.com/samyang-roundsquare/aws-common-ops/refs/heads/main/cicd"
TARGET_DIR="$HOME/cicd" # 사용자 홈 디렉토리 하위에 생성

# 5. Domain Configuration
echo "Enter your domain name (e.g., jenkins.example.com):"
read -r DOMAIN_NAME < /dev/tty

if [ -z "$DOMAIN_NAME" ]; then
    echo "Domain name is required. Using default 'your-domain.com'."
    DOMAIN_NAME="your-domain.com"
fi

# 6. Start Services
echo "[4/4] Starting CI/CD Services..."

mkdir -p "$TARGET_DIR/nginx/conf.d"
mkdir -p "$TARGET_DIR/nginx/certs"
mkdir -p "$TARGET_DIR/nginx/html"

echo "Downloading docker-compose.cicd.yml..."
curl -sSL "$BASE_URL/docker-compose.cicd.yml" -o "$TARGET_DIR/docker-compose.yml"

echo "Downloading README.md..."
curl -sSL "$BASE_URL/README.md" -o "$TARGET_DIR/README.md"

echo "Downloading nginx/conf.d/default.conf..."
curl -sSL "$BASE_URL/nginx/conf.d/default.conf" -o "$TARGET_DIR/nginx/conf.d/default.conf"

cd "$TARGET_DIR"

# 도메인 설정 적용
if [ -n "$DOMAIN_NAME" ] && [ "$DOMAIN_NAME" != "your-domain.com" ]; then
    echo "Configuring Nginx and Docker Compose with domain: $DOMAIN_NAME"
    sed -i "s/your-domain.com/$DOMAIN_NAME/g" "$TARGET_DIR/nginx/conf.d/default.conf"
    sed -i "s/your-domain.com/$DOMAIN_NAME/g" "$TARGET_DIR/docker-compose.yml"
fi

# 이메일 설정 (Certbot용)
# SSH 키 생성 시 입력한 이메일이 있다면 사용, 없으면 물어봄
if [ -z "$EMAIL" ]; then
    echo "Enter your email address for SSL certificate (Certbot):"
    read -r EMAIL < /dev/tty
fi

if [ -n "$EMAIL" ] && [ "$EMAIL" != "your-email@example.com" ]; then
    echo "Configuring Docker Compose with email: $EMAIL"
    sed -i "s/your-email@example.com/$EMAIL/g" "$TARGET_DIR/docker-compose.yml"
fi

# PEM 파일 처리
mkdir -p "$TARGET_DIR/keys"
PEM_FOUND=0
MAIN_PEM=""

# 현재 디렉토리(스크립트 실행 위치)에서 PEM 파일을 찾음
# 주의: cd $TARGET_DIR을 했으므로, 원래 위치($CURRENT_DIR)를 참조해야 함
if ls "$CURRENT_DIR"/*.pem 1> /dev/null 2>&1; then
    echo "Copying PEM files from $CURRENT_DIR to $TARGET_DIR/keys..."
    cp "$CURRENT_DIR"/*.pem "$TARGET_DIR/keys/"
    chmod 400 "$TARGET_DIR/keys/"*.pem
    PEM_FOUND=1
    
    # 메인 PEM 파일 결정 (key.pem 우선, 없으면 첫 번째 파일)
    if [ -f "$TARGET_DIR/keys/key.pem" ]; then
        MAIN_PEM="keys/key.pem"
    else
        FIRST_PEM=$(ls "$TARGET_DIR/keys/"*.pem | head -n 1)
        MAIN_PEM="keys/$(basename "$FIRST_PEM")"
    fi
fi

if [ $PEM_FOUND -eq 1 ]; then
    # .env 파일 생성
    echo "PEM_FILE=$MAIN_PEM" > .env
    echo "Configured docker-compose to use $MAIN_PEM as default identity."
    echo "All PEM files are mounted to /var/jenkins_home/.ssh/keys"
else
    echo "No PEM file to configure. Using default 'keys/key.pem' (which may not exist)."
    echo "PEM_FILE=keys/key.pem" > .env
fi

echo "Starting Docker Compose..."
docker compose up -d

echo "=========================================="
echo " Jenkins Setup Complete!"
echo "=========================================="
echo "1. Environment verified."
echo "2. PEM files processed."
echo "3. CI/CD files downloaded to $TARGET_DIR."
echo "4. Services started via Docker Compose."
echo ""
echo "To check status:"
echo "  cd $TARGET_DIR"
echo "  docker compose ps"
echo "=========================================="
