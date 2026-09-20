# Challenges

Six Terraform configurations with deliberate defects. Each one gives you a
**symptom**, not an error message — the same thing production gives you.

> These files are excluded from `terraform validate`, `terraform fmt -check`,
> tflint, checkov and Trivy in CI. They are supposed to be broken. A green build
> must never depend on someone un-breaking the curriculum.

| # | Challenge | Difficulty | Defects | Budget | Skills tested |
|---|---|---|---|---|---|
| 1 | [Fix the routing](challenge-01-fix-routing.tf) | Beginner | 2 | 10 min | Route tables, subnet associations |
| 2 | [Fix the security group](challenge-02-fix-security.tf) | Beginner | 2 | 10 min | Ingress and egress, silent failures |
| 3 | [Fix the auto scaling](challenge-03-fix-autoscaling.tf) | Intermediate | 2 | 15 min | ASG health check types, target registration |
| 4 | [Fix the launch template](challenge-04-fix-launch-template.tf) | Intermediate | 2 | 15 min | `user_data`, security group assignment |
| 5 | [Fix the load balancer](challenge-05-fix-load-balancer.tf) | Intermediate | 2 | 15 min | Internal vs internet-facing, listener config |
| 6 | [Full stack debug](challenge-06-full-debug.tf) | Advanced | 4 | 30 min | Everything above, no hints in the file |

Solutions are in [`../solutions/`](../solutions/). Opening one before you have
solved the challenge costs 600 points — see the
[facilitator guide](../docs/GAMEDAY_FACILITATOR_GUIDE.md#4-scoring).

## The debugging sequence

Work in this order. It is ordered by how cheap each check is, not by how likely
the defect is.

1. **Routing** — is there a path from the internet to the VPC, and back out?
2. **Security** — are the right ports open, in *both* directions?
3. **Compute** — are instances running the software you think they are?
4. **Load balancing** — is the ALB attached to targets that are actually healthy?

## The attach pattern

Most defects here are a resource that exists but was never connected to
anything. Terraform reports success. Nothing works.

| Symptom | Missing attachment |
|---|---|
| Nothing can reach the VPC | Route table not associated with the subnets |
| Requests time out with no error | Security group has no egress rule |
| ALB returns 503 | ASG not registered with the target group |
| Targets never turn healthy | Launch template has no security group, or no `user_data` |
| ALB returns 504 | ALB is `internal`, or the listener port does not match the target port |

## What a scanner would have caught

Run a policy scanner over these files and compare its findings with what you
actually had to debug:

```bash
checkov -d . --compact
```

At time of writing that reports **51 passed, 39 failed**. Now ask the useful
question: how many of the defects *you* just fixed appear in that list? Most do
not. "The route table was never associated" is a correctness defect, not a
policy violation — which is why `terraform test` assertions exist alongside
scanners in the parent repository.
