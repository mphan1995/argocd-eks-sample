# Security Tools

- SBOM: syft (ưu tiên), ORT (cài thủ công nếu cần).
- Scan: trivy (fallback placeholder nếu thiếu DB/tool).
- Sign: cosign (keypair local trong pipeline/output/keys).

UI Tools có thể trigger cài đặt nhanh (curl/pip) với fallback hướng dẫn thủ công.
ORT cần cài thủ công (release + Java 17+), không có installer tự động.

Gợi ý cài đặt (tùy hệ):
- syft: https://github.com/anchore/syft
- ort: https://github.com/oss-review-toolkit/ort
- trivy: https://github.com/aquasecurity/trivy
- cosign: https://github.com/sigstore/cosign
