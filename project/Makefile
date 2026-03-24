.PHONY: help setup tf-init tf-apply tf-destroy build ingest dbt-run dbt-test pipeline kestra-up kestra-down clean

help:
	@echo "US Wildfire Analytics Pipeline — Makefile targets"
	@echo ""
	@echo "  make setup        Copy .env.example -> .env (then edit it)"
	@echo "  make tf-init      Initialise Terraform"
	@echo "  make tf-apply     Provision GCP infrastructure (GCS + BigQuery)"
	@echo "  make tf-destroy   Tear down all GCP infrastructure"
	@echo "  make build        Build all Docker images"
	@echo "  make ingest       Run the ingestion pipeline (Kaggle -> GCS -> BigQuery)"
	@echo "  make dbt-run      Run all dbt models"
	@echo "  make dbt-test     Run all dbt tests"
	@echo "  make pipeline     Run ingest + dbt-run + dbt-test in sequence"
	@echo "  make kestra-up    Start Kestra orchestrator (http://localhost:8080)"
	@echo "  make kestra-down  Stop Kestra orchestrator"
	@echo "  make clean        Remove local build artefacts"

setup:
	@if [ ! -f .env ]; then cp .env.example .env; echo ".env created — please fill in your values"; else echo ".env already exists"; fi

tf-init:
	cd terraform && terraform init

tf-apply:
	cd terraform && terraform apply -var-file=terraform.tfvars

tf-destroy:
	cd terraform && terraform destroy -var-file=terraform.tfvars

build:
	docker compose -f docker/docker-compose.yaml build

ingest:
	docker compose -f docker/docker-compose.yaml run --rm ingestion

dbt-run:
	docker compose -f docker/docker-compose.yaml run --rm dbt \
	  run --profiles-dir /dbt --project-dir /dbt

dbt-test:
	docker compose -f docker/docker-compose.yaml run --rm dbt \
	  test --profiles-dir /dbt --project-dir /dbt

pipeline: ingest dbt-run dbt-test
	@echo "Pipeline complete."

kestra-up:
	docker compose -f kestra/docker-compose.yaml up -d
	@echo "Kestra UI: http://localhost:8080"

kestra-down:
	docker compose -f kestra/docker-compose.yaml down

clean:
	docker compose -f docker/docker-compose.yaml down --rmi local --volumes
	rm -rf dbt_wildfire/target dbt_wildfire/dbt_packages
