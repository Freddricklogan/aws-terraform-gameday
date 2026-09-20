# Case Study — AWS Terraform Game Day

**Repository:** [aws-terraform-gameday](https://github.com/Freddricklogan/aws-terraform-gameday) · **Live demo:** [freddricklogan.github.io/aws-terraform-gameday](https://freddricklogan.github.io/aws-terraform-gameday/) · **Author:** Freddrick Logan

---

## 1. Who has this problem

An instructor who has to teach cloud infrastructure to people who will be hired to run it: a university IT programme, a workforce bootcamp, an internal academy at a company moving to the cloud. The same problem sits with the engineering manager who discovers a new hire can follow a tutorial but cannot diagnose a load balancer returning 503 at two in the morning. Engineers are hired for the second and trained on the first.

## 2. The problem, as a scenario

An instructor wants to run a Game Day: give students a broken AWS stack and score them on finding out why. The starting configuration is a public tutorial. It works — and ships SSH open to the world, compute in public subnets, unencrypted volumes, no logging, and state on a laptop. Used as-is, students learn to debug a stack they should never build. Hardened by hand, the semester starts before it is finished. Either way there is no rubric, no facilitator guide, and no way to prove the hardened version is hardened.

## 3. What it costs to leave it alone

Graduates who carry insecure defaults into production, and employers who pay for the second education on the job. Institutionally, a course that cannot demonstrate its own rigour: a security office asked to approve a student AWS lab has nothing to point at but good intentions. I will not put a figure on insecure infrastructure; the AWS Well-Architected security pillar ([docs.aws.amazon.com/wellarchitected](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)), which I use with students, describes the exposure as specific misconfigurations, and every one was present in the original tutorial.

## 4. The approach, and the alternative I rejected

I kept the two halves together and made each honest. The reference stack — load balancer in public subnets, Auto Scaling group in private subnets, logging and state in a separate boundary — was rebuilt as four Terraform modules with pinned providers, validated variables, a tagging strategy, and a CI pipeline that formats, validates, lints, runs `terraform test` against mocked providers, and scans with Checkov and Trivy on every commit. The curriculum — six broken-infrastructure challenges with graduated hints, worked solutions and a rubric that rewards diagnosis over speed — is preserved intact and excluded from CI, so a green build never depends on un-breaking the exercises. A console page on GitHub Pages walks a reviewer through.

The alternative I rejected was to fix the tutorial in place and add a checklist. That leaves security posture as an assertion. Modules with tests and a scanner in CI make it something a security office can read and re-run; the audit file records what each check found, what was skipped and why, and what was not run.

## 5. What the code does today

Real: the four modules, root composition, variable validation, three `terraform test` suites under mocked providers with no AWS account, the Checkov and Trivy scans, the six challenges, the facilitator guide, and the console page. The `plan` and `apply` jobs exist but are gated behind a manual trigger and a protected environment; nothing in CI touches a real account.

Simulated: nothing is random, but the console's numbers — challenges, planted defects, modules, controls, session length — are computed from the repository's content, not a live deployment.

Worth knowing: the audit file lists the scanner findings accepted with inline reasons rather than silenced, and six residual risks — no WAF, AWS-managed rather than customer-managed keys for log buckets, a single NAT gateway by default — with what would close each. It also records my own results from the March 2026 Illinois Tech Game Day the material was built for.

## 6. Evidence

Measured in continuous integration on the current main branch: `terraform validate` passes for the root and all four modules; `terraform test` reports 26 passed, 0 failed under mocked providers; Checkov reports 144 passed, 0 failed, 15 documented inline skips; tflint and Trivy run clean in the same pipeline. The audit's earlier local scan with Checkov 3.3.19 reported 148 passed, 0 failed, 16 skips — the difference is scanner version — against a baseline of 28 passed and 20 failed for the original configuration. The console page returns zero console errors in headless Chrome.

## 7. What it would take to run this in production

The stack is a teaching reference, so "production" means two things. To run the Game Day for a cohort: an AWS Organizations sandbox with a budget alarm per team, the OpenID Connect trust already wired in the workflow so no long-lived keys exist, and a facilitator — the guide covers timing, scoring and failure modes for three hours. To run the stack as real infrastructure: a WAF in front of the load balancer, customer-managed keys for the log buckets, one NAT gateway per availability zone, drift detection, and TLS to the targets. That is days of Terraform, itemised in the audit's residual-risk table.

## 8. Limits and next steps

The tests run against mocked providers, so they prove composition and policy, not that AWS accepts the plan; the gated `plan` job does that on demand. The challenges assume a single region and a small team. Next: an OPA/Conftest policy pack so the security rules are written once and reused across repositories, and Infracost in pull requests so a change's cost is visible before approval.

## 9. Who should look at this

**Hiring manager:** evidence that I can harden infrastructure to a scanner-clean state and prove it in CI, while keeping the teaching material that was the point.
**Consulting client:** a template for hands-on cloud training that a security office can approve, with the audit trail already written.
**Engineer:** read `modules/` and `tests/*.tftest.hcl` for how `terraform test` with mocked providers asserts security posture without an account; the audit file shows the before-and-after.
