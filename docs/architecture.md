# Architecture

## Thành phần
- infra: docker-compose cho Gitea, Jenkins, Registry; kind cho runtime.
- scm: cấu hình Gitea tối giản.
- ci: Jenkins Dockerfile + JCasC.
- artifact: Docker Registry (Nexus tùy chọn).
- pipeline: bash stages chuẩn hóa logging, output, artifact.
- app: sample app + Helm chart.
- ui: Flask dashboard, lưu state trên filesystem.

## Luồng
1. Code ở Gitea.
2. Jenkins gọi pipeline scripts.
3. Build/Test tạo image và push Registry.
4. SBOM/Scan/Sign tạo artifacts bảo mật.
5. Deploy lên kind bằng Helm.
6. Verify gọi endpoint, kết quả phản hồi qua UI và logs.
