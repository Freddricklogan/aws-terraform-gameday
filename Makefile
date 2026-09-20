# =============================================================================
# aws-terraform-gameday -- developer and facilitator entry points.
#
#   make help      list every target
#   make lint      fmt check + validate + tflint
#   make test      terraform test (offline, mocked providers)
#   make scan      checkov + trivy config
#   make plan      terraform plan
#   make apply     terraform apply (asks for confirmation)
#   make destroy   terraform destroy (asks twice)
#
# TF_DIRS is every directory containing first-party Terraform we own.
# challenges/ is deliberately excluded: those files are broken on purpose.
# =============================================================================

SHELL        := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help init lint fmt fmt-check validate tflint test scan checkov trivy plan plan-json apply destroy docs-serve clean pre-commit

TF          ?= terraform
TF_DIRS     := . modules/network modules/compute modules/alb modules/observability
PLAN_FILE   ?= tfplan.binary
VAR_FILE    ?= terraform.tfvars

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## terraform init (no backend; pass BACKEND=1 to use backend.tf)
ifeq ($(BACKEND),1)
	$(TF) init -input=false
else
	$(TF) init -backend=false -input=false
endif

fmt: ## Rewrite Terraform files to canonical format
	$(TF) fmt -recursive $(TF_DIRS) tests

fmt-check: ## Fail if any Terraform file is unformatted
	$(TF) fmt -check -recursive -diff $(TF_DIRS) tests

validate: ## terraform validate against the root composition
	$(TF) validate -no-color

tflint: ## Lint for deprecated syntax and AWS-specific mistakes
	tflint --init
	tflint --recursive --minimum-failure-severity=warning

lint: fmt-check validate tflint ## fmt-check + validate + tflint

test: ## Run terraform test (mocked providers, no AWS calls, no cost)
	$(TF) test

checkov: ## Static security analysis of the Terraform
	checkov --directory . --config-file .checkov.yaml

trivy: ## Misconfiguration scan with Trivy
	trivy config --severity HIGH,CRITICAL --skip-dirs challenges --exit-code 1 .

scan: checkov trivy ## Run every security scanner

plan: ## Show the planned changes
	$(TF) plan -input=false -var-file=$(VAR_FILE) -out=$(PLAN_FILE)

plan-json: plan ## Emit the plan as JSON (used by the CI policy steps)
	$(TF) show -json $(PLAN_FILE) > tfplan.json

apply: ## Apply the saved plan, or plan and apply interactively
	@if [ -f "$(PLAN_FILE)" ]; then \
	  $(TF) apply -input=false "$(PLAN_FILE)"; \
	else \
	  $(TF) apply -input=false -var-file=$(VAR_FILE); \
	fi

destroy: ## Tear everything down (Game Day accounts must end at zero)
	@echo "This destroys every resource in the current workspace."
	@read -p "Type the environment name to confirm: " env; \
	  $(TF) destroy -input=false -var-file=$(VAR_FILE) -var="environment=$$env"

outputs: ## Print the stack outputs
	@$(TF) output 2>/dev/null || echo "No state yet. Run 'make apply' first."

pre-commit: ## Run every pre-commit hook against all files
	pre-commit run --all-files

docs-serve: ## Preview the Game Day console at http://localhost:8080
	@echo "Serving docs/ at http://localhost:8080 -- Ctrl-C to stop"
	@python3 -m http.server 8080 --directory docs

clean: ## Remove local Terraform caches and plan artefacts
	rm -rf .terraform
	rm -f $(PLAN_FILE) tfplan.json
	@echo "Cleared. The lock file is kept on purpose -- run 'make init' next."
