# CI/CD 환경 구축 가이드

이 디렉토리는 Jenkins, Nginx, Certbot을 포함한 CI/CD 환경 구축을 위한 Docker Compose 설정을 포함하고 있습니다.

## 사전 요구사항

- **Docker & Docker Compose**: 서버에 Docker와 Docker Compose가 설치되어 있어야 합니다.
- **도메인 이름**: 이 서버의 IP 주소를 가리키는 유효한 도메인 이름이 필요합니다.
- **PEM 키**: 다른 서버에 접근하기 위한 SSH 개인 키(예: `key.pem`)가 스크립트를 실행하는 디렉토리에 존재해야 합니다. 스크립트가 자동으로 `.pem` 파일을 찾아 설정합니다.

## 서버 초기화 (선택 사항)

이 환경을 구축하기 전에 서버가 초기화되어 있어야 합니다.

1.  **서버 초기화**: `aws-linux-ec2-init.sh`를 실행하여 Docker, AWS CLI 등 기본 환경을 구성합니다.
    ```bash
    curl -fsSL https://raw.githubusercontent.com/samyang-roundsquare/aws-common-ops/refs/heads/main/aws-linux-ec2-init.sh | sh
    ```

2.  **Jenkins 설치 및 실행**: `aws-linux-ec2-jenkins.sh`를 실행하여 CI/CD 파일을 다운로드하고 서비스를 시작합니다.
    ```bash
    curl -fsSL https://raw.githubusercontent.com/samyang-roundsquare/aws-common-ops/refs/heads/main/cicd/aws-linux-ec2-jenkins.sh | sh
    ```


## 디렉토리 구조

```
cicd/
├── docker-compose.yml       # 메인 Docker Compose 파일 (Repo: docker-compose.cicd.yml)
├── README.md                # 본 가이드
├── key.pem                  # SSH 개인 키 (사용자가 직접 제공해야 함)
└── nginx/
    ├── conf.d/
    │   └── default.conf     # Nginx 설정
    └── certs/               # SSL 인증서 (자동 생성됨)
```

## 설정 단계

1.  **SSH 키 준비 (GitHub 연결용)**:
    Jenkins가 GitHub 저장소에 접근하기 위해서는 SSH 키가 필요합니다.
    
    - **자동 생성 (권장)**: 스크립트 실행 시 `.pem` 파일이 없다면 자동으로 키 생성을 안내합니다. 이메일 주소를 입력하면 키가 생성되고, GitHub에 등록할 공개키가 화면에 표시됩니다.
    - **수동 준비**: 이미 키가 있다면 스크립트 실행 디렉토리에 위치시키세요. 또는 다음 명령어로 직접 생성할 수 있습니다.
        ```bash
        # 키 생성 (이메일 주소는 GitHub 계정 이메일)
        ssh-keygen -t ed25519 -C "your_email@example.com" -f key.pem
        # 비밀번호(passphrase)는 입력하지 않고 엔터를 누릅니다.
        ```

    **GitHub에 공개키 등록 (자동 생성 시 스크립트가 안내함)**
    - GitHub 저장소 > Settings > Deploy keys > Add deploy key
    - Title: `Jenkins CI` (원하는 이름)
    - Key: 공개키 내용 붙여넣기
    - [x] Allow write access (빌드 결과 태깅 등이 필요한 경우 체크)
    **수동 준비 후 GitHub에 공개키(Public Key) 등록**
    - 생성된 `key.pem.pub` 파일의 내용을 복사하여 GitHub 저장소 > Settings > Deploy keys > Add deploy key에 등록합니다.
    
    **개인키(Private Key) 배치**
    - 생성된 `key.pem` (개인키) 파일을 스크립트를 실행할 디렉토리에 위치시킵니다.
    - 만약 배포 대상 서버 접속용 PEM 파일이 따로 있다면 함께 위치시킵니다 (예: `worker-key.pem`).
    
    ```bash
    ls *.pem
    # key.pem (GitHub용)
    # worker-key.pem (배포 서버 접속용)
    ```
    
    - 스크립트가 자동으로 모든 `.pem` 파일을 감지하여 Jenkins 컨테이너의 `/var/jenkins_home/.ssh/keys/` 경로에 마운트합니다.
    - `key.pem`이 존재하거나 첫 번째로 발견된 PEM 파일은 기본 ID(`id_rsa`)로도 설정됩니다.
        > **참고**: `id_rsa`는 Jenkins가 Git 저장소(GitHub 등)에 접근할 때 사용하는 기본 SSH 키입니다. 반면, `/var/jenkins_home/.ssh/keys/`에 마운트된 다른 PEM 파일들은 배포 대상 서버(Worker, API 등)에 SSH로 접속할 때 명시적으로 사용됩니다 (예: `ssh -i ...`).

2.  **도메인 설정**:
    스크립트 실행 시 도메인 이름을 입력받아 자동으로 설정합니다 (`nginx/conf.d/default.conf` 및 `docker-compose.yml`).
    - 만약 수동으로 변경해야 한다면 해당 파일들을 열어 `your-domain.com`을 실제 도메인 이름으로 변경하세요.

3.  **서비스 시작**:
    다음 명령어를 실행하여 서비스를 시작하세요:
    ```bash
    docker compose up -d
    ```

4.  **SSL 인증서 설정**:
    스크립트 실행 시 이메일을 입력받아 `docker-compose.yml`에 설정합니다.
    `certbot` 서비스가 시작될 때 인증서가 없다면 자동으로 발급을 시도합니다.
    
    *참고: 초기 인증서 발급이 실패하거나 수동으로 실행해야 할 경우 다음 명령어를 사용하세요:*
    ```bash
    docker compose run --rm certbot certonly --webroot --webroot-path=/usr/share/nginx/html --email your-email@example.com --agree-tos --no-eff-email -d your-domain.com
    ```
    인증서 발급 성공 후, `nginx/conf.d/default.conf`에서 SSL 인증서 관련 주석을 해제하고 Nginx를 재로드하세요 (스크립트가 자동으로 설정하지 않은 경우):
    ```bash
    docker compose exec nginx nginx -s reload
    ```

## Jenkins 접속

- 브라우저를 열고 `https://your-domain.com` (SSL 설정 전이라면 `http://your-domain.com`)으로 접속하세요.
- Jenkins 잠금 해제를 위해 초기 관리자 비밀번호를 확인하세요:
    ```bash
    docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
    ```
