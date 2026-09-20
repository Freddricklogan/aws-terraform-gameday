#!/usr/bin/env bash
# =============================================================================
# Tear down every resource in the current workspace.
#
# A Game Day account should end the day at zero. NAT gateways and load
# balancers bill by the hour whether or not anyone is looking at them.
# =============================================================================
set -euo pipefail

VAR_FILE="${VAR_FILE:-terraform.tfvars}"

echo "================================================"
echo "  AWS Terraform Game Day -- teardown"
echo "================================================"
echo

if [ ! -d .terraform ]; then
  echo "Not initialised in this directory. Run 'make init' first, or cd to the repo root." >&2
  exit 1
fi

echo "Workspace: $(terraform workspace show 2>/dev/null || echo default)"
echo
echo "Resources currently tracked in state:"
terraform state list 2>/dev/null || echo "  (none)"
echo

read -r -p "Type DESTROY to tear all of this down: " confirm
if [ "$confirm" != "DESTROY" ]; then
  echo "Aborted. Nothing was changed."
  exit 0
fi

terraform destroy -auto-approve -var-file="$VAR_FILE"

echo
echo "Destroy complete. Verify that nothing is left billing:"
echo "  aws ec2 describe-nat-gateways --filter Name=state,Values=available"
echo "  aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'"
echo "  aws ec2 describe-instances --filters Name=instance-state-name,Values=running \\"
echo "      --query 'Reservations[].Instances[].InstanceId'"
echo
echo "The ALB access log bucket is force_destroy = true, so its objects go with it."
