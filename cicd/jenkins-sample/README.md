# Jenkins 배포 Job 샘플

이 디렉토리는 Jenkins에서 여러 서버에 PEM 키를 사용하여 배포하는 예제 Jenkinsfile을 포함합니다.

## 파일 구조

```
jenkins-sample/
├── Jenkinsfile.deploy        # 단일 서버 배포 예제
├── Jenkinsfile.multi-server   # 다중 서버 배포 예제
└── README.md                  # 본 가이드
```

## 사전 요구사항

### 1. PEM 키 파일 준비

각 배포 서버별로 PEM 키 파일을 준비하여 Jenkins가 실행되는 위치에 배치합니다:

```bash
# 예제 디렉토리 구조
cicd/
├── keys/
│   ├── worker-key.pem    # Worker 서버 접속 키
│   ├── api-key.pem       # API 서버 접속 키
│   └── web-key.pem       # Web 서버 접속 키
```

aws-linux-ec2-jenkins.sh 스크립트 실행 시 모든 PEM 파일이 자동으로 `/var/jenkins_home/.ssh/keys/`에 마운트됩니다.

### 2. 서버 정보 설정

Jenkinsfile의 `environment` 섹션에서 다음 정보를 실제 환경에 맞게 수정:

```groovy
environment {
    // SSH 키 경로
    WORKER_KEY = '/var/jenkins_home/.ssh/keys/worker-key.pem'
    API_KEY = '/var/jenkins_home/.ssh/keys/api-key.pem'
    WEB_KEY = '/var/jenkins_home/.ssh/keys/web-key.pem'

    // 서버 접속 정보 (user@ip 형식)
    WORKER_HOST = 'ec2-user@10.0.1.10'
    API_HOST = 'ec2-user@10.0.2.20'
    WEB_HOST = 'ec2-user@10.0.3.30'

    // Git 저장소
    GIT_REPO = 'git@github.com:your-org/your-repo.git'
}
```

### 3. 배포 서버 준비

각 배포 대상 서버에 배포 스크립트를 준비합니다:

**예제: `/home/ec2-user/app/deploy-worker.sh`**
```bash
#!/bin/bash
set -e

echo "Starting Worker deployment..."

# 환경 변수 로드
if [ -f .env ]; then
    source .env
fi

# 의존성 설치
echo "Installing dependencies..."
npm install

# 애플리케이션 빌드
echo "Building application..."
npm run build

# Docker Compose로 서비스 재시작
echo "Restarting services..."
docker compose down
docker compose up -d

# 헬스 체크
sleep 5
curl -f http://localhost:3000/health || exit 1

echo "Worker deployment completed successfully!"
```

**예제: `/home/ec2-user/app/deploy-api.sh`**
```bash
#!/bin/bash
set -e

echo "Starting API deployment..."

# 환경 설정
source .env

# Python 의존성 설치
pip install -r requirements.txt

# 데이터베이스 마이그레이션
python manage.py migrate

# Gunicorn 재시작
sudo systemctl restart gunicorn
sudo systemctl restart nginx

echo "API deployment completed!"
```

## 사용 방법

### 방법 1: 단일 서버 배포 (Jenkinsfile.deploy)

1. Jenkins에서 새로운 Pipeline Job 생성
2. Pipeline 설정에서 다음과 같이 구성:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: 프로젝트 Git 저장소 URL
   - Script Path: `Jenkinsfile.deploy`

3. Job 실행 시 파라미터 선택:
   - **TARGET_SERVER**: 배포할 서버 선택 (worker, api, web)
   - **BRANCH**: 배포할 Git 브랜치 (기본값: main)

4. 빌드 실행

### 방법 2: 다중 서버 배포 (Jenkinsfile.multi-server)

1. Jenkins에서 새로운 Pipeline Job 생성
2. Pipeline 설정:
   - Definition: Pipeline script from SCM
   - Script Path: `Jenkinsfile.multi-server`

3. Job 실행 시 파라미터 선택:
   - **DEPLOY_WORKER**: Worker 서버에 배포 (체크박스)
   - **DEPLOY_API**: API 서버에 배포 (체크박스)
   - **DEPLOY_WEB**: Web 서버에 배포 (체크박스)
   - **BRANCH**: 배포할 Git 브랜치

4. 원하는 서버를 선택하고 빌드 실행

## 배포 프로세스

두 Jenkinsfile 모두 다음 단계로 배포를 진행합니다:

1. **Checkout**: Git 저장소에서 소스코드 체크아웃
2. **Prepare Deployment**: 배포 대상 서버 정보 설정
3. **Deploy to Server**:
   - SSH로 대상 서버 접속
   - Git 저장소 업데이트 (없으면 클론)
   - 배포 스크립트 실행 (deploy-{server}.sh)
4. **Verify Deployment**: 배포 결과 확인

## SSH 키 관리

### Jenkins에서 PEM 키 사용

aws-linux-ec2-jenkins.sh 스크립트를 통해 설정된 경우, 모든 PEM 파일은 다음 경로에 마운트됩니다:

```
/var/jenkins_home/.ssh/keys/
├── worker-key.pem
├── api-key.pem
└── web-key.pem
```

### SSH 연결 테스트

Jenkins 컨테이너 내부에서 SSH 연결 테스트:

```bash
docker compose exec jenkins bash

# 키 권한 설정
chmod 400 /var/jenkins_home/.ssh/keys/worker-key.pem

# SSH 연결 테스트
ssh -o StrictHostKeyChecking=no \
    -i /var/jenkins_home/.ssh/keys/worker-key.pem \
    ec2-user@10.0.1.10 'echo "Connection successful"'
```

## 배포 스크립트 예제

각 서버 타입별 배포 스크립트 예제:

### Node.js 애플리케이션 (deploy-web.sh)

```bash
#!/bin/bash
set -e

PROJECT_DIR="/home/ec2-user/app"
cd $PROJECT_DIR

echo "Deploying Web application..."

# 의존성 설치
npm ci

# 빌드
npm run build

# PM2로 애플리케이션 재시작
pm2 restart ecosystem.config.js --update-env

echo "Web deployment completed!"
```

### Python API (deploy-api.sh)

```bash
#!/bin/bash
set -e

PROJECT_DIR="/home/ec2-user/app"
cd $PROJECT_DIR

echo "Deploying API server..."

# 가상환경 활성화
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt

# 정적 파일 수집
python manage.py collectstatic --noinput

# 데이터베이스 마이그레이션
python manage.py migrate

# Gunicorn 재시작
sudo systemctl restart api-server

echo "API deployment completed!"
```

### Docker Compose 애플리케이션 (deploy-worker.sh)

```bash
#!/bin/bash
set -e

PROJECT_DIR="/home/ec2-user/app"
cd $PROJECT_DIR

echo "Deploying Worker service..."

# 환경 변수 확인
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Docker 이미지 빌드
docker compose build

# 서비스 재시작
docker compose down
docker compose up -d

# 헬스 체크
sleep 10
docker compose ps

echo "Worker deployment completed!"
```

## 트러블슈팅

### SSH 연결 실패

```bash
# Jenkins 컨테이너에서 키 권한 확인
docker compose exec jenkins ls -la /var/jenkins_home/.ssh/keys/

# 키 권한이 올바른지 확인 (400 또는 600)
# 필요시 Jenkinsfile에서 chmod 400 실행
```

### Git 클론 실패

```bash
# 대상 서버에서 GitHub SSH 키 등록 확인
ssh -T git@github.com

# known_hosts에 github.com 추가
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### 배포 스크립트 실행 권한 오류

```bash
# 대상 서버에서 스크립트 권한 확인
ls -la /home/ec2-user/app/deploy-*.sh

# 실행 권한 부여
chmod +x /home/ec2-user/app/deploy-*.sh
```

## 추가 참고사항

- **보안**: PEM 키 파일은 절대 Git 저장소에 커밋하지 마세요
- **백업**: 배포 전 데이터베이스 백업을 권장합니다
- **롤백**: 배포 실패 시 이전 버전으로 롤백할 수 있도록 준비하세요
- **모니터링**: 배포 후 애플리케이션 로그와 메트릭을 확인하세요

## 관련 문서

- [Jenkins Pipeline 공식 문서](https://www.jenkins.io/doc/book/pipeline/)
- [SSH Agent Plugin](https://plugins.jenkins.io/ssh-agent/)
- [Docker Compose 배포 가이드](https://docs.docker.com/compose/)
