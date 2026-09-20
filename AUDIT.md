# Infrastructure Audit — `aws-terraform-gameday`

A file-by-file review of the original configuration, the defects found, what was
changed, and what was deliberately left alone. Findings are ordered by severity.

**Scope reviewed:** `main.tf`, `provider.tf`, `variables.tf`, `outputs.tf`,
`terraform.tfvars`, `install-env.sh`, `Makefile`, `.gitignore`,
`scripts/{setup-aws-cli,setup-terraform,validate,destroy}.sh`,
`challenges/*.tf` (6 files), `solutions/*.md` (6 files), `docs/*.md` (6 files),
`README.md`.

**Measured baseline.** Checkov 3.3.19 against the original root configuration
(`main.tf`, `provider.tf`, `variables.tf`, `outputs.tf`):

```
Passed checks: 28, Failed checks: 20, Skipped checks: 0
```

**Measured result.** Checkov 3.3.19 against the refactored tree (root +
`modules/`, `challenges/` excluded):

```
Passed checks: 148, Failed checks: 0, Skipped checks: 16
```

All 16 skips are inline `checkov:skip=` annotations on the resource, each with a
written reason. None are global suppressions. Run `grep -rn "checkov:skip="` to
review every exception in one screen.

---

## Severity 1 — exploitable as written

### 1.1 SSH open to the entire internet
`main.tf` → `aws_vpc_security_group_ingress_rule.ssh` allowed `0.0.0.0/0` on TCP
22 for every instance. Combined with 1.2 (instances in public subnets with public
IPs) this put an SSH daemon on the public internet on day one. Checkov
`CKV_AWS_24`.

**Fixed.** Port 22 does not appear anywhere in the new configuration. Operator
access is AWS Systems Manager Session Manager, granted by the
`AmazonSSMManagedInstanceCore` policy on the instance role
(`modules/compute/main.tf`). Session Manager is authenticated by IAM, logged by
CloudTrail, and needs no inbound rule at all.

### 1.2 Application instances in public subnets with auto-assigned public IPs
Every subnet was public (`map_public_ip_on_launch = true`) and the Auto Scaling
group launched directly into them. Each instance had its own internet-routable
address, so the load balancer was decorative from a security standpoint — an
attacker could address instances directly and bypass it. Checkov `CKV_AWS_88`,
`CKV_AWS_130`.

**Fixed.** `modules/network` now builds two tiers: public subnets that hold only
the ALB and the NAT gateway (`map_public_ip_on_launch = false`), and private
subnets with no route to an internet gateway that hold the Auto Scaling group.
`associate_public_ip_address = false` in the launch template.

### 1.3 IMDSv1 permitted — instance role credentials reachable via SSRF
The launch template had no `metadata_options` block, so the instance metadata
service accepted unauthenticated `GET /latest/meta-data/iam/security-credentials/`.
Any SSRF or misbehaving dependency in the web tier could read the role's
credentials. Checkov `CKV_AWS_79`, `CKV_AWS_341`.

**Fixed.** `http_tokens = "required"` and `http_put_response_hop_limit = 1` in
`modules/compute`. The bootstrap script was rewritten to fetch a token first.
Asserted by `tests/security_hardening.tftest.hcl`.

### 1.4 One security group shared by the load balancer and the instances
`aws_security_group.web` was attached to both the ALB and every instance, and
allowed all egress to `0.0.0.0/0`. There was no boundary between the tiers: a
rule written for the ALB silently applied to the application. Checkov
`CKV_AWS_382`, `CKV_AWS_277`, `CKV_AWS_23` (no descriptions on any rule).

**Fixed.** Two security groups in `modules/alb`. The ALB accepts the listener
port from `var.ingress_cidrs` and egresses **only** to the app security group by
reference. The app group accepts **only** the app port from the ALB group by
reference, and egresses on 80/443 for package installs through the NAT gateway.
Every rule carries a `description`.

---

## Severity 2 — no evidence, no recovery

### 2.1 No logging of any kind
No ALB access logs, no VPC flow logs, no CloudWatch log group, no alarms.
After an incident there was nothing to read. Checkov `CKV_AWS_91`.

**Fixed.** New `modules/observability`: an S3 bucket for ALB access logs
(SSE-S3, versioned, public access blocked, TLS-only bucket policy, lifecycle
expiry), a CloudWatch log group plus a least-privilege IAM role for VPC flow
logs capturing `ALL` traffic, and a KMS-encrypted SNS topic. `modules/alb` adds
`UnHealthyHostCount` and `HTTPCode_Target_5XX_Count` alarms.

### 2.2 No remote state, no locking
State was local. Two facilitators applying at once would clobber each other, and
the state file — which contains resource attributes you would not publish — lived
on a laptop with no versioning and no recovery.

**Fixed.** `backend.tf.example` documents an S3 backend with `encrypt = true`,
a `dynamodb_table` lock and an optional KMS key, using placeholder values only
(no real account IDs, bucket names or ARNs). Bootstrap requirements for the
backend bucket and lock table are written out in the file's header comment.

### 2.3 Unencrypted EBS volumes
No `block_device_mappings` at all, so root volumes took the account default,
which is unencrypted unless someone has turned on EBS encryption-by-default.

**Fixed.** Explicit encrypted `gp3` root volume with
`delete_on_termination = true` and an optional customer-managed KMS key
(`var.kms_key_arn`).

### 2.4 ALB served HTTP only, with no hardening flags
No HTTPS listener, no `drop_invalid_header_fields`, no
`desync_mitigation_mode`, no access logs, no deletion protection. Checkov
`CKV_AWS_2`, `CKV_AWS_131`, `CKV_AWS_328`, `CKV_AWS_150`, `CKV2_AWS_74`.

**Fixed.** `drop_invalid_header_fields = true` and
`desync_mitigation_mode = "defensive"` unconditionally. Setting
`var.certificate_arn` creates an HTTPS listener on a TLS 1.3 / 1.2 policy and
turns port 80 into a 301 redirect. Deletion protection is a variable, default
`false` so a Game Day can be destroyed, and documented as such.

---

## Severity 3 — correctness and operability

### 3.1 Unpinned AMI resolved by `most_recent`
`data "aws_ami" "ubuntu"` filtered only on virtualisation type and architecture
with `most_recent = true`, so it matched *any* Canonical image — including
minimal, non-LTS and preview builds — and resolved differently from one day to
the next. Two facilitators running the same commit could get different operating
systems. Checkov `CKV_AWS_386` (image name confusion).

**Fixed.** The AMI now comes from Canonical's published SSM public parameter for
Ubuntu 22.04 LTS amd64, which is region-aware, deterministic per region, and
cannot match an unrelated image.

### 3.2 No `versions.tf`; provider constraint on the wrong major line
`provider.tf` pinned `aws ~> 6.0` while the configuration used 5.x-era
idioms, and there was **no `required_version`** at all, so any Terraform from
0.12 up would attempt it.

**Fixed.** `versions.tf` at the root and in every module:
`required_version = ">= 1.9.0, < 2.0.0"` and `aws ~> 5.60`. 1.9 is the floor
because the configuration uses cross-variable `validation` blocks and
`terraform test` mocking.

### 3.3 Provider pointed at a long-lived credentials file
`shared_credentials_files = ["~/.aws/credentials"]` hard-wired the provider to a
static access key on disk and made CI impossible without planting one. Checkov
`CKV_AWS_41` passed only because no key was literally inline.

**Fixed.** Removed. The provider uses the default credential chain: SSO or a
named profile locally, and GitHub OIDC role assumption in CI. No long-lived key
exists anywhere in the repository or its secrets.

### 3.4 No variable validation
Nine variables, none with a `validation` block. `desired_capacity = 9` with
`max_size = 5` was accepted by `terraform plan` and failed minutes into the
apply, with an AWS API error rather than a useful message.

**Fixed.** Every root and module variable now has at least one `validation`
block — CIDR shape, RFC 1918 membership, region format, naming charset and
length (including the 32-character ALB name ceiling), allowed environments,
ARN shapes, port ranges, retention floors, and a cross-variable check that
`min_size <= desired_capacity <= max_size`. 17 validation rules are proved to
fire by `tests/variable_validation.tftest.hcl`.

### 3.5 No tagging strategy
Only `Name` was set, by hand, per resource, and the ASG propagated a single tag.
Nothing carried an owner, a cost centre or a data classification, so nothing
could be attributed on a bill or in an incident.

**Fixed.** `provider "aws"` declares `default_tags` from `local.common_tags`:
`Project`, `Environment`, `Owner`, `CostCenter`, `DataClassification`,
`ManagedBy`, `Repository`, plus `var.additional_tags`. A validation block
prevents `additional_tags` from shadowing reserved keys.

### 3.6 Default security group left wide open
Terraform never adopted `aws_default_security_group`, so the VPC's default group
kept its permissive self-referencing rules — and anything launched outside
Terraform would land in it. Checkov `CKV2_AWS_12`.

**Fixed.** `modules/network` adopts it and declares no rules, which strips it.

### 3.7 `health_check_type = "ELB"` with no target group attachment
The root `main.tf` set ELB health checks on the ASG but registered the target
group via a separate `aws_autoscaling_attachment`. That works, but it separates
the health-check decision from the attachment that makes it meaningful, and it
is precisely the failure mode Challenge 3 teaches.

**Changed.** `target_group_arns` is now set on the ASG itself, next to
`health_check_type`, with a comment naming it as the line that prevents the 503.
Also added: `instance_refresh`, `capacity_rebalance`, `enabled_metrics`, and a
CPU target-tracking policy.

### 3.8 Fragile subnet CIDR list
`subnet_cidrs` was a hand-written list of three `/24`s that had to stay in sync
with `az_count` and with `vpc_cidr` by convention alone. A mismatch produced an
index-out-of-range error at apply time.

**Fixed.** `modules/network` derives both tiers with `cidrsubnet()` from
`var.vpc_cidr` and `var.az_count`, so they cannot drift apart or overlap.

### 3.9 `.gitignore` excluded the provider lock file
`.terraform.lock.hcl` was listed. That file is *meant* to be committed: it is
what makes a provider version reproducible and checksum-verified across
machines.

**Fixed.** Removed from `.gitignore`, with a comment explaining why. Added
ignores for `tfplan*`, `*.tfvars` (with a negation for `*.tfvars.example`),
`backend.tf` and scanner output.

---

## Severity 4 — process and supply chain

### 4.1 No CI, no tests, no scanning
There was no `.github/` directory. Nothing checked formatting, validity, policy
or security on a pull request; nothing prevented a broken commit from being the
thing a facilitator cloned on the morning of the event.

**Fixed.** `.github/workflows/deploy.yml`:
`lint` (fmt-check, root and per-module validate, tflint) → `test`
(`terraform test`, no credentials configured so it *cannot* reach AWS) →
`security-scan` (checkov + Trivy config, both uploading SARIF to code scanning)
→ `plan` on pull requests, commenting the plan and uploading the artefact →
`deploy` on `main`, gated behind the `aws-lab` GitHub environment with a required
reviewer → `pages`, publishing `docs/`. All AWS jobs use OIDC role assumption
(`id-token: write`) with `vars.AWS_ROLE_ARN`; there are no long-lived keys.
`.github/workflows/codeql.yml` analyses the JavaScript in `docs/` and the
workflow definitions weekly.

An Infracost step is included in `deploy.yml`, commented out and documented: it
turns "this PR adds a NAT gateway" into a number on the pull request, but it
needs an API key the repository does not have.

### 4.2 No pre-commit hooks
Formatting and policy were enforced by memory.

**Fixed.** `.pre-commit-config.yaml` with pinned revisions:
`terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_checkov`,
`terraform_trivy`, `terraform_docs`, plus `gitleaks` for secret detection,
`detect-private-key`, and `shellcheck` on the shell scripts.

### 4.3 Setup script installed an unverified, unpinned binary
`scripts/setup-terraform.sh` added the HashiCorp apt repository and installed
whatever `terraform` resolved to at that moment.

**Fixed.** The script now installs a pinned version and verifies the download
against HashiCorp's published `SHA256SUMS` before unpacking.

### 4.4 Secrets handling
No secrets were committed — that was already correct, and `.gitignore` covered
state and `*.auto.tfvars`. Two weaknesses remained: `terraform.tfvars` was
committed (harmless today, but it is the file people put secrets in), and
nothing scanned for accidental secrets.

**Fixed.** `terraform.tfvars` is replaced by `terraform.tfvars.example` and the
real file is git-ignored. `gitleaks` runs in pre-commit. `user_data` carries no
secrets and the bootstrap template says so in a comment, because `user_data` is
readable by anything that can reach the metadata service.

---

## Teaching material — reviewed, kept, not "fixed"

`challenges/` contains six Terraform files with deliberate defects. Scanned on
their own they report:

```
checkov -d challenges/ →  Passed checks: 51, Failed checks: 39, Skipped checks: 0
```

**Those 39 findings are the curriculum, not a regression.** The files are
excluded from `terraform validate`, `terraform fmt -check`, tflint, checkov and
Trivy in CI and in `.checkov.yaml` / `.pre-commit-config.yaml`, because a green
build must not depend on un-breaking the exercises. The facilitator guide uses
the 39-finding scan as a session segment: run the scanner on the broken configs
and show what would have been caught before the apply.

Preserved unchanged: all six challenge files, all six solution write-ups, the
six reference documents in `docs/`, and the Game Day results section of the
README.

---

## Residual risks — accepted, not solved

| Risk | Why it is accepted | What would close it |
|---|---|---|
| No WAF in front of the ALB (`CKV2_AWS_28`) | Teaching stack, no user data, and a WAFv2 web ACL adds standing cost | Add an `aws_wafv2_web_acl` with the AWS managed core and Log4j rule sets, associated with the ALB |
| Flow logs and ALB logs use AWS-managed keys, not a CMK (`CKV_AWS_158`, `CKV_AWS_145`) | ALB access log delivery only supports SSE-S3; a CMK makes delivery fail | Customer-managed KMS key for CloudWatch Logs; accept SSE-S3 for the ALB bucket |
| Flow log retention defaults to 90 days, not 365 (`CKV_AWS_338`) | Cost, in a training account | Raise `var.log_retention_days` to 365 in any regulated environment |
| Backend traffic is HTTP inside the VPC (`CKV_AWS_378`) | TLS terminates at the ALB; targets are reachable only from the ALB security group | Per-instance certificates and an HTTPS target group |
| Single NAT gateway by default | Cost control; documented in `terraform.tfvars.example` | `single_nat_gateway = false` for one NAT per AZ |
| No drift detection schedule | Out of scope for this pass | A scheduled `terraform plan -detailed-exitcode` workflow that opens an issue on exit code 2 |

---

## Verification actually performed in this pass

| Check | Tool | Ran? | Result |
|---|---|---|---|
| IaC security scan, refactored tree | Checkov 3.3.19 | **Yes** | 148 passed, 0 failed, 16 documented inline skips |
| IaC security scan, original config | Checkov 3.3.19 | **Yes** | 28 passed, 20 failed (baseline) |
| IaC security scan, `challenges/` | Checkov 3.3.19 | **Yes** | 51 passed, 39 failed (intentional) |
| HCL2 parse of all 30 `.tf` / `.tftest.hcl` files | `python-hcl2` | **Yes** | 0 parse failures |
| `terraform init -backend=false` | Terraform CLI | **No** | Binary unavailable — see below |
| `terraform validate` | Terraform CLI | **No** | Binary unavailable |
| `terraform fmt -check` | Terraform CLI | **No** | Binary unavailable; canonical attribute alignment applied by script instead |
| `terraform test` | Terraform CLI | **No** | Binary unavailable |
| `tflint` | tflint | **No** | Binary unavailable |
| `trivy config` | Trivy | **No** | Binary unavailable |

**Why.** The sandbox this refactor was written in reaches PyPI but not
`releases.hashicorp.com` or `github.com` — both return `403` at the egress
proxy. Terraform, tflint and Trivy are distributed only from those hosts, so
none of them could be installed. The only Terraform distribution reachable via
PyPI is `terraform-binary`, which ships Terraform **0.11** and cannot parse this
configuration at all. Checkov installed from PyPI and ran for real; its attempt
to fetch remediation guidance from `api0.prismacloud.io` was blocked by the same
proxy, which does not affect the scan itself.

Consequently: the security posture has been scanned, and the syntax has been
parsed, but **`terraform validate`, `terraform fmt -check`, `terraform test` and
`tflint` have not been executed against this tree.** They run on the first CI
job (`lint` and `test` in `deploy.yml`) and can be run locally with `make lint`
and `make test`. No claim is made here about their output.
