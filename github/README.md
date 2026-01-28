# GitHub CLI 설치 및 인증 가이드

Amazon Linux/RHEL/CentOS 환경에서 GitHub CLI를 설치하고 인증하는 방법을 안내합니다.

## 사전 준비

이 가이드는 다음 환경에서 실행됩니다:
- Amazon Linux
- RHEL (Red Hat Enterprise Linux)
- CentOS
- yum 패키지 관리자를 사용하는 Linux 배포판

## 설치 단계

### 1. 시스템 업데이트

먼저 시스템을 최신 상태로 업데이트합니다:

```bash
sudo yum update -y && sudo yum upgrade -y
```

### 2. 필수 개발 도구 설치

GitHub CLI 설치 및 사용에 필요한 개발 도구와 라이브러리를 설치합니다:

```bash
sudo yum install -y gcc libcurl-devel libffi-devel openssl-devel python3 python3-pip
```

**설치되는 패키지 설명:**
- `gcc`: C 컴파일러 (일부 패키지 빌드에 필요)
- `libcurl-devel`: cURL 개발 라이브러리 (HTTP 통신)
- `libffi-devel`: Foreign Function Interface 개발 라이브러리
- `openssl-devel`: OpenSSL 개발 라이브러리 (암호화 및 보안)
- `python3`: Python 3 인터프리터
- `python3-pip`: Python 패키지 관리자

### 3. GitHub CLI 설치

GitHub CLI를 설치합니다. 이 예제에서는 버전 2.37.0을 설치합니다:

```bash
sudo yum install -y https://github.com/cli/cli/releases/download/v2.37.0/gh_2.37.0_linux_amd64.rpm
```

> **참고**: 최신 버전을 설치하려면 [GitHub CLI 릴리스 페이지](https://github.com/cli/cli/releases)에서 최신 버전의 RPM 패키지 URL을 확인하세요.

### 4. 설치 확인

설치가 완료되었는지 확인합니다:

```bash
gh --version
```

정상적으로 설치되었다면 GitHub CLI 버전 정보가 출력됩니다.

## 인증 설정

### 1. GitHub CLI 인증 시작

다음 명령어로 GitHub 인증 프로세스를 시작합니다:

```bash
gh auth login
```

### 2. 인증 방법 선택

인증 방법을 선택하라는 프롬프트가 나타납니다:

1. **GitHub.com** 또는 **GitHub Enterprise Server** 선택
2. **HTTPS** 또는 **SSH** 프로토콜 선택
3. **Git Credential Manager** 또는 **Login with a web browser** 선택

### 3. 디바이스 인증 (웹 브라우저 방식)

웹 브라우저를 통한 인증을 선택한 경우:

1. 터미널에 표시된 디바이스 코드를 복사합니다
2. 다음 URL로 이동합니다:
   ```
   https://github.com/login/device
   ```
3. 디바이스 코드를 입력하고 인증을 완료합니다
4. 터미널에서 인증 완료 메시지를 확인합니다

### 4. 인증 확인

인증이 완료되었는지 확인합니다:

```bash
gh auth status
```

## 사용 예제

인증이 완료되면 GitHub CLI를 사용할 수 있습니다:

```bash
# 저장소 목록 조회
gh repo list

# 이슈 목록 조회
gh issue list

# Pull Request 목록 조회
gh pr list

# 저장소 클론
gh repo clone owner/repo-name
```

## 문제 해결

### 설치 오류

**문제**: RPM 패키지 설치 실패
- **해결**: 네트워크 연결을 확인하고, 최신 버전의 패키지 URL을 사용하세요

**문제**: 의존성 패키지 누락
- **해결**: `sudo yum install -y epel-release`를 실행하여 EPEL 저장소를 활성화하세요

### 인증 오류

**문제**: `gh auth login` 실패
- **해결**: 
  - 네트워크 연결 확인
  - 방화벽 설정 확인
  - 프록시 환경인 경우 프록시 설정 확인

**문제**: 디바이스 코드 만료
- **해결**: `gh auth login`을 다시 실행하여 새로운 코드를 받으세요

## 추가 리소스

- [GitHub CLI 공식 문서](https://cli.github.com/manual/)
- [GitHub CLI GitHub 저장소](https://github.com/cli/cli)
- [GitHub CLI 릴리스](https://github.com/cli/cli/releases)
