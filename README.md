# DevOps - CI/CD Pipeline Local

Nền tảng CI/CD full local cho WSL: SCM → CI → Artifact → Build/Test → SBOM → Scan → Sign → Deploy → Verify → Feedback.

## Kiến trúc tổng quan
- SCM: Gitea.
- CI: Jenkins (JCasC).
- Artifact: Docker Registry (Nexus tùy chọn).
- Pipeline: bash stages + output/logs chuẩn hóa.
- Deploy: kind + Helm.
- UI: Flask dashboard, lưu state trên filesystem.

## Quickstart
```bash
cp .env.example .env
make bootstrap
make up
make ui
```

Truy cập:
- UI: http://127.0.0.1:5001
- Gitea: http://127.0.0.1:3000
- Jenkins: http://127.0.0.1:8080
- Registry: http://127.0.0.1:5000

## Chạy UI
```bash
make ui
```
Chế độ dev:
```bash
make ui-dev
```
Trong UI, vào trang Tools để kiểm tra và cài đặt tool bị thiếu.

## Chạy pipeline
```bash
make run-all
```
Stage riêng:
```bash
make run-build
make run-test
make run-sbom
make run-scan
make run-sign
make run-deploy
make run-verify
```

## Jenkins
- Mở http://127.0.0.1:8080
- Admin mặc định: lấy từ `JENKINS_ADMIN_USER/JENKINS_ADMIN_PASSWORD` trong `.env`.
- Tạo Pipeline job và dùng `ci/jenkins/jobs/Jenkinsfile`.

## Troubleshooting WSL
- Docker Desktop + WSL2 integration phải bật.
- Lỗi push/pull registry local: thêm `{"insecure-registries":["localhost:5000"]}` vào Docker daemon config.
- Jenkins không chạy được docker: kiểm tra mount `/var/run/docker.sock` và quyền user trong nhóm docker.
- kind tạo cluster lỗi: chạy `kind delete cluster --name local-max` rồi thử lại.
