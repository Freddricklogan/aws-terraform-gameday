#!/usr/bin/env bash
# =============================================================================
# Pre-flight check for a Game Day workstation.
#
# Reports what is present and what is missing. Only the Terraform checks are
# fatal; AWS credentials are not needed to lint, test or scan this repository.
# =============================================================================
set -uo pipefail

FAIL=0
ok()   { printf '  \033[32m%-6s\033[0m %s\n' "OK"   "$1"; }
warn() { printf '  \033[33m%-6s\033[0m %s\n' "WARN" "$1"; }
bad()  { printf '  \033[31m%-6s\033[0m %s\n' "FAIL" "$1"; FAIL=1; }

echo
echo "Required"
echo "--------"

if command -v terraform >/dev/null 2>&1; then
  ok "terraform $(terraform version -json 2>/dev/null | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p' | head -1)"
else
  bad "terraform not installed -- run: bash scripts/setup-terraform.sh"
fi

if command -v git >/dev/null 2>&1; then ok "git $(git --version | awk '{print $3}')"; else bad "git not installed"; fi

echo
echo "Recommended"
echo "-----------"

command -v tflint   >/dev/null 2>&1 && ok "tflint"   || warn "tflint not installed -- make lint will fail"
command -v checkov  >/dev/null 2>&1 && ok "checkov"  || warn "checkov not installed -- pip install checkov"
command -v trivy    >/dev/null 2>&1 && ok "trivy"    || warn "trivy not installed -- make scan will fail"
command -v pre-commit >/dev/null 2>&1 && ok "pre-commit" || warn "pre-commit not installed -- pip install pre-commit"
command -v aws      >/dev/null 2>&1 && ok "aws cli"  || warn "aws cli not installed -- only needed to apply"

echo
echo "AWS access (only needed for plan/apply)"
echo "---------------------------------------"

if command -v aws >/dev/null 2>&1; then
  if IDENTITY="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)"; then
    ok "authenticated as ${IDENTITY}"
    REGION="$(aws configure get region 2>/dev/null || echo '')"
    [ -n "$REGION" ] && ok "region ${REGION}" || warn "no default region -- terraform.tfvars will decide"
  else
    warn "not authenticated -- 'aws sso login' or 'aws configure'. Lint, test and scan still work."
  fi
fi

echo
echo "Repository checks"
echo "-----------------"

if command -v terraform >/dev/null 2>&1; then
  terraform fmt -check -recursive . modules tests >/dev/null 2>&1 \
    && ok "formatting is canonical" \
    || warn "formatting drift -- run: make fmt"

  if [ -d .terraform ]; then
    terraform validate -no-color >/dev/null 2>&1 \
      && ok "terraform validate passes" \
      || bad "terraform validate fails -- run: terraform validate"
  else
    warn "not initialised -- run: make init"
  fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Ready. Next: make test"
else
  echo "Fix the FAIL lines above before continuing." >&2
fi
exit "$FAIL"
