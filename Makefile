# Terraform workflow shortcuts
# Usage: make init, make plan, make apply, make destroy

.PHONY: init validate plan apply destroy fmt clean status check

init:
	terraform init

validate:
	terraform validate

fmt:
	terraform fmt -recursive

plan: validate
	terraform plan

apply: validate
	terraform apply

destroy:
	terraform destroy

# Show deployed resources
status:
	@terraform state list 2>/dev/null || echo "No state file found. Run 'make apply' first."

# Show outputs (load balancer URL, etc.)
output:
	@terraform output 2>/dev/null || echo "No outputs found. Run 'make apply' first."

# Full pre-flight check
check: fmt validate
	@echo "All checks passed."

# Remove local terraform cache (does not affect deployed resources)
clean:
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	@echo "Local cache cleared. Run 'make init' before next apply."
