SHELL := /bin/bash

.PHONY: bootstrap up down reset health ui ui-dev run-all run-build run-test run-sbom run-scan run-sign run-deploy run-verify logs

bootstrap:
	@bash scripts/bootstrap_wsl.sh

up:
	@bash scripts/start_stack.sh

down:
	@bash scripts/stop_stack.sh

reset:
	@CONFIRM=YES bash scripts/reset_all.sh

health:
	@bash scripts/healthcheck.sh

ui:
	@if [ -x ui/.venv/bin/python ]; then \
		ui/.venv/bin/python ui/app.py | tee ui/ui.log; \
	else \
		python3 ui/app.py | tee ui/ui.log; \
	fi

ui-dev:
	@if [ -x ui/.venv/bin/python ]; then \
		FLASK_DEBUG=1 ui/.venv/bin/python ui/app.py | tee ui/ui.log; \
	else \
		FLASK_DEBUG=1 python3 ui/app.py | tee ui/ui.log; \
	fi

run-all:
	@RUN_ID=$$(date +%Y%m%d-%H%M%S); \
	RUN_DIR="$(PWD)/pipeline/output/$$RUN_ID"; \
	export RUN_ID RUN_DIR; \
	export WORKSPACE="$(PWD)"; \
	export TAG="$$RUN_ID"; \
	for s in pipeline/stages/01_build.sh pipeline/stages/02_test.sh pipeline/stages/03_sbom.sh pipeline/stages/04_scan.sh pipeline/stages/05_sign.sh pipeline/stages/06_deploy.sh pipeline/stages/07_verify.sh; do \
		bash $$s; \
	done

run-build:
	@bash pipeline/stages/01_build.sh

run-test:
	@bash pipeline/stages/02_test.sh

run-sbom:
	@bash pipeline/stages/03_sbom.sh

run-scan:
	@bash pipeline/stages/04_scan.sh

run-sign:
	@bash pipeline/stages/05_sign.sh

run-deploy:
	@bash pipeline/stages/06_deploy.sh

run-verify:
	@bash pipeline/stages/07_verify.sh

logs:
	@bash -c 'LATEST=$$(ls -1t pipeline/output/*/logs/*.log 2>/dev/null | head -n 1); if [ -n "$$LATEST" ]; then echo "Tail: $$LATEST"; tail -n 200 -F "$$LATEST"; else echo "Chưa có log pipeline."; fi'
