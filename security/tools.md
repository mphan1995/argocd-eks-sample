# Security Tools

- SBOM: syft (ưu tiên), ORT (placeholder nếu chưa cấu hình).
- Scan: trivy (fallback placeholder nếu thiếu DB/tool).
- Sign: cosign (keypair local trong pipeline/output/keys).

UI Tools có thể trigger cài đặt nhanh (curl/pip) với fallback hướng dẫn thủ công.

Gợi ý cài đặt (tùy hệ):
- syft: https://github.com/anchore/syft
- trivy: https://github.com/aquasecurity/trivy
- cosign: https://github.com/sigstore/cosign
