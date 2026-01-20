# Lab Guide

## Lab 1: Bootstrap và chạy UI
- Chạy `make bootstrap`, `make up`, `make ui`.
- Mở UI và kiểm tra trạng thái stack.

## Lab 2: Chạy pipeline theo stage
- Chạy `make run-build`, `make run-test`, `make run-sbom`.
- So sánh log trong `pipeline/output/<run_id>/logs`.

## Lab 3: Policy và kiểm soát bảo mật
- Chỉnh `security/policies/policy.sample.yml`.
- Thử bật/tắt tool scan (Trivy) và xem fallback.
