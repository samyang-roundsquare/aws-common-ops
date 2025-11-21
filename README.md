# AWS EC2 Initialization & Route53 Automation

This repository contains scripts to initialize an AWS EC2 instance (Amazon Linux/RHEL/CentOS) and automate Route53 DNS updates for dynamic IPs.

## Scripts

### `aws-linux-ec2-init.sh`

This is the main unified initialization script. It performs the following:

1.  **System Setup**:
    *   Sets Timezone to `Asia/Seoul`.
    *   Installs `git`, `docker`, `cronie`, `jq`.
    *   Installs Docker Compose Plugin.
    *   Configures Docker to start on boot.
2.  **AWS Configuration**:
    *   Interactively asks for AWS Access Key, Secret Key, and Region.
    *   Configures `aws` CLI.
3.  **Route53 Setup**:
    *   Asks for the Domain Name (e.g., `example.com`).
    *   Automatically finds the Hosted Zone ID from Route53.
4.  **Helper Script Generation**:
    *   Generates `/usr/local/bin/auto-update-route53.sh`: Core logic for updating DNS.
    *   Generates `/usr/local/bin/aws-service-boot.sh`: Wrapper script with saved credentials.

#### Usage

**Option 1: Quick Install (via curl)**

Run the following command:
```bash
curl -fsSL https://raw.githubusercontent.com/samyang-roundsquare/aws-common-ops.git/refs/heads/main/aws-linux-ec2-init.sh | sh
```

**Option 2: Manual Install**

If you cannot access the public repository:

1.  Upload `aws-linux-ec2-init.sh` to your EC2 instance.
2.  Make it executable:
    ```bash
    chmod +x aws-linux-ec2-init.sh
    ```
3.  Run with root privileges:
    ```bash
    sudo ./aws-linux-ec2-init.sh
    ```
4.  Follow the interactive prompts.

---

### Generated Scripts

After running the init script, the following scripts will be available in `/usr/local/bin/`:

#### `aws-service-boot.sh`

This script is a wrapper that calls `auto-update-route53.sh` with the credentials and configuration you provided during initialization.

*   **Usage**: Run this script on boot or via cron to ensure your DNS record always points to the current EC2 Public IP.
*   **Security Note**: This file contains your AWS credentials. Ensure it is readable only by root (`chmod 700`).

#### `auto-update-route53.sh`

This script handles the logic of checking the current Public IP and updating the Route53 A record if it has changed.

*   **Usage**:
    ```bash
    ./auto-update-route53.sh <AccessKey> <SecretKey> <HostedZoneID> <Domain>
    ```

## Automation (User Data / Cron)

To automatically update Route53 on reboot, you can add the following to your EC2 User Data or Crontab:

```bash
/usr/local/bin/aws-service-boot.sh
```

---

# AWS EC2 초기화 및 Route53 자동화 (Korean)

이 저장소는 AWS EC2 인스턴스(Amazon Linux/RHEL/CentOS)를 초기화하고 동적 IP에 대한 Route53 DNS 업데이트를 자동화하는 스크립트를 포함하고 있습니다.

## 스크립트

### `aws-linux-ec2-init.sh`

통합 초기화 스크립트입니다. 다음 작업을 수행합니다:

1.  **시스템 설정**:
    *   타임존을 `Asia/Seoul`로 설정합니다.
    *   `git`, `docker`, `cronie`, `jq`를 설치합니다.
    *   Docker Compose 플러그인을 설치합니다.
    *   부팅 시 Docker가 실행되도록 설정합니다.
2.  **AWS 구성**:
    *   AWS Access Key, Secret Key, Region을 대화형으로 입력받습니다.
    *   `aws` CLI를 구성합니다.
3.  **Route53 설정**:
    *   도메인 이름(예: `example.com`)을 입력받습니다.
    *   Route53에서 해당 도메인의 Hosted Zone ID를 자동으로 찾습니다.
4.  **보조 스크립트 생성**:
    *   `/usr/local/bin/auto-update-route53.sh`: DNS 업데이트를 위한 핵심 로직을 생성합니다.
    *   `/usr/local/bin/aws-service-boot.sh`: 저장된 자격 증명을 사용하는 래퍼 스크립트를 생성합니다.

#### 사용법

**옵션 1: 빠른 설치 (curl 사용)**

다음 명령어를 실행합니다:
```bash
curl -fsSL https://raw.githubusercontent.com/samyang-roundsquare/aws-common-ops.git/refs/heads/main/aws-linux-ec2-init.sh | sh
```

**옵션 2: 수동 설치**

Public 저장소에 접근할 수 없는 경우:

1.  `aws-linux-ec2-init.sh` 파일을 EC2 인스턴스에 업로드합니다.
2.  실행 권한을 부여합니다:
    ```bash
    chmod +x aws-linux-ec2-init.sh
    ```
3.  루트 권한으로 실행합니다:
    ```bash
    sudo ./aws-linux-ec2-init.sh
    ```
4.  화면의 안내에 따라 정보를 입력합니다.

---

### 생성되는 스크립트

초기화 스크립트를 실행하면 다음 스크립트들이 `/usr/local/bin/` 경로에 생성됩니다:

#### `aws-service-boot.sh`

초기화 과정에서 입력한 자격 증명과 설정을 사용하여 `auto-update-route53.sh`를 호출하는 래퍼 스크립트입니다.

*   **사용법**: 부팅 시 또는 cron을 통해 이 스크립트를 실행하면 DNS 레코드가 항상 현재 EC2 공인 IP를 가리키도록 할 수 있습니다.
*   **보안 주의**: 이 파일에는 AWS 자격 증명이 포함되어 있습니다. 루트 사용자만 읽을 수 있도록 설정해야 합니다 (`chmod 700`).

#### `auto-update-route53.sh`

현재 공인 IP를 확인하고 변경된 경우 Route53 A 레코드를 업데이트하는 로직을 처리하는 스크립트입니다.

*   **사용법**:
    ```bash
    ./auto-update-route53.sh <AccessKey> <SecretKey> <HostedZoneID> <Domain>
    ```

## 자동화 (User Data / Cron)

재부팅 시 자동으로 Route53을 업데이트하려면 EC2 User Data 또는 Crontab에 다음을 추가하세요:

```bash
/usr/local/bin/aws-service-boot.sh
```
