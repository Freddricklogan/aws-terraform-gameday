#!/usr/bin/env bash
# =============================================================================
# Install a pinned, checksum-verified Terraform on Ubuntu/Debian.
#
# The previous version of this script added the HashiCorp apt repository and
# installed whatever `terraform` happened to resolve to. That is not
# reproducible: two people running it a week apart got different versions, and
# nothing verified what was downloaded.
#
# Usage:  bash scripts/setup-terraform.sh [version]
#         TF_VERSION=1.9.8 bash scripts/setup-terraform.sh
# =============================================================================
set -euo pipefail

TF_VERSION="${1:-${TF_VERSION:-1.9.8}}"
OS="linux"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

BASE="https://releases.hashicorp.com/terraform/${TF_VERSION}"
ZIP="terraform_${TF_VERSION}_${OS}_${ARCH}.zip"
SUMS="terraform_${TF_VERSION}_SHA256SUMS"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Downloading Terraform ${TF_VERSION} (${OS}/${ARCH})..."
curl -fsSL -o "${WORKDIR}/${ZIP}"  "${BASE}/${ZIP}"
curl -fsSL -o "${WORKDIR}/${SUMS}" "${BASE}/${SUMS}"

echo "Verifying checksum..."
(
  cd "$WORKDIR"
  # Check only our file; the SUMS file lists every platform.
  grep " ${ZIP}\$" "${SUMS}" | sha256sum --check --status
)
echo "Checksum OK."

# Optional but recommended: verify the signature on the SHA256SUMS file with
# HashiCorp's release GPG key before trusting it.
#   curl -fsSL -o "${SUMS}.sig" "${BASE}/${SUMS}.sig"
#   gpg --verify "${SUMS}.sig" "${SUMS}"

unzip -q -o "${WORKDIR}/${ZIP}" -d "$WORKDIR"
sudo install -m 0755 "${WORKDIR}/terraform" /usr/local/bin/terraform

echo
terraform version
echo
echo "Next steps:"
echo "  make init     # terraform init -backend=false"
echo "  make lint     # fmt -check, validate, tflint"
echo "  make test     # terraform test against mocked providers (no AWS, no cost)"
