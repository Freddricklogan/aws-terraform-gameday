# Game Day Facilitator Guide

How to run a three-hour AWS/Terraform Game Day with this repository. Written for
the person at the front of the room, not the people debugging.

The short version: teams get infrastructure that is broken in a specific,
recoverable way, and a symptom instead of an error message. They are scored on
how they diagnose, not on how fast they type.

---

## 1. Session shapes

| Shape | Duration | Challenges | Teams | Needs an AWS account? |
|---|---|---|---|---|
| **Lightning** | 45 min | 1, 2 | Pairs | No — plan only |
| **Standard** | 3 hours | 1–5 | 3–4 people | Optional |
| **Full** | 4 hours | 1–6 | 3–4 people | Yes, one per team |
| **Zero-cost** | 90 min | 1–6, read-only | Any | No |

The **zero-cost** shape is the one to pick if budget or account provisioning is
in doubt. Teams read the broken config, predict the failure, then verify their
prediction with `terraform plan` and `checkov`. No resource is ever created.
It loses the satisfaction of a working URL and loses nothing else.

---

## 2. Before the day

**Two weeks out**
- [ ] Decide the session shape. If it involves an apply, request accounts now.
- [ ] Set an AWS Budget alert per account (USD 20 is generous for this stack).
- [ ] Confirm every account can create VPCs, NAT gateways, ALBs and IAM roles.

**One week out**
- [ ] Ask participants to run `bash scripts/setup-terraform.sh` and
      `bash scripts/validate.sh` on their own machine and report failures.
- [ ] Send them `docs/aws-concepts.md` and `docs/terraform-guide.md` as pre-reading.
- [ ] Decide how hints are requested (a shared channel works better than raised hands).

**The morning of**
- [ ] `git pull && make lint && make test` on your own machine. If CI is green,
      this takes a minute and rules out "it was broken before we started".
- [ ] Open the Game Day console (`make docs-serve`, or the published Pages site)
      on the projector. It is the room's shared reference for the topology.
- [ ] Have `docs/cheat-sheet.md` printed. People who are stuck stop reading screens.

---

## 3. Running the session

### 3.1 Open (15 min)

Put the architecture diagram up and walk the four trust boundaries in one pass:
internet → ALB in public subnets → ASG in private subnets → logs and state.
Then say the sentence the whole day rests on:

> Most of what breaks today will be a resource that exists but was never
> attached to anything. Terraform will report success. Nothing will work.

### 3.2 Warm-up (20 min) — the scanner segment

Run a security scanner against the deliberately broken teaching configs in front
of the room:

```bash
checkov -d challenges/ --compact
```

At time of writing that reports **51 passed, 39 failed**. Ask which of the 39 the
scanner would have caught *before* anyone opened a console, and which ones it
cannot see — because "the route table was never associated" is a correctness
defect, not a policy violation. That distinction is worth more to most teams than
any single challenge.

Then run the same scanner on the real configuration (`make checkov`) and show a
clean result with sixteen written exceptions. Exceptions with reasons are the
professional artefact, not zero findings.

### 3.3 Challenges (90–150 min)

Release challenges in order. Do not release the next one until roughly half the
room has cleared the current one — a team that is two behind stops learning and
starts copying.

| # | Title | Difficulty | Defects | Budget | What it teaches |
|---|---|---|---|---|---|
| 1 | Fix the routing | Beginner | 2 | 10 min | Creating ≠ attaching |
| 2 | Fix the security group | Beginner | 2 | 10 min | Silent failure vs refusal; egress matters |
| 3 | Fix the auto scaling | Intermediate | 2 | 15 min | ELB vs EC2 health checks; target registration |
| 4 | Fix the launch template | Intermediate | 2 | 15 min | user_data; the default-SG trap |
| 5 | Fix the load balancer | Intermediate | 2 | 15 min | internal vs internet-facing; listener/target port |
| 6 | Full stack debug | Advanced | 4 | 30 min | All of the above, no hints in the file |

For each challenge, read the **symptom** aloud and nothing else. The symptom is
in the file header and on the console page. Resist explaining the AWS service
involved; that is the diagnosis you are asking them to perform.

### 3.4 Debrief (30 min)

Per team, three questions, in this order:

1. What was the symptom, in one sentence?
2. What did you check first, and what did it rule out?
3. What would have caught this before the apply — a scanner, a `terraform test`
   assertion, a plan review, or nothing?

Question 3 is the one that transfers to their actual job. Point at
`tests/security_hardening.tftest.hcl` and show that the ELB health check type and
the target group attachment — the subjects of challenge 3 — are both asserted
there, offline, for free.

---

## 4. Scoring

Points reward diagnosis, not speed. A team that explains the failure and fixes it
in twenty minutes should beat a team that guessed correctly in five.

| Event | Points |
|---|---|
| Challenge solved, correct root cause explained | 1000 |
| Challenge solved, root cause not explained | 600 |
| Hint 1 revealed (a nudge) | −100 |
| Hint 2 revealed (the mechanism) | −200 |
| Hint 3 revealed (effectively the answer) | −400 |
| Solution file opened before solving | −600 |
| Correct prediction of the symptom *before* applying | +250 |
| Naming a control that would have prevented it | +250 |
| Leaving resources running at the end of the session | −1000 |

Hints are graduated on purpose and are visible on the console page behind a
toggle, so revealing one is a deliberate act a team has to decide on together.

That last row is not a joke. Cost discipline is part of the competency being
taught, and the only way to make it land is to score it.

---

## 5. When it goes wrong

| Situation | What to do |
|---|---|
| A team's apply fails with an IAM error | Their account is missing a permission, not their config. Move them to the zero-cost path immediately; do not debug IAM in front of the room. |
| `terraform apply` hangs on the ALB | ALB creation takes 2–4 minutes. NAT gateway takes 1–2. This is normal; use the wait to ask question 3 from the debrief early. |
| Instances are healthy but the URL times out | Almost always challenge 5's defect in the wild: check `internal` and check the listener port against the target group port. |
| A team is 40 minutes behind | Give them hint 3 for free and move them forward. A team stuck on challenge 1 at the halfway point learns nothing more from challenge 1. |
| Someone's state is corrupted | `terraform state list`, then `terraform import` the orphan, or destroy and re-apply. With remote state and locking configured this is rare; without it, it is the day's most likely disaster. |
| The room runs out of time | Stop at the debrief, not at the last challenge. The debrief is where the learning consolidates. |

---

## 6. Closing the day

Non-negotiable, in this order:

```bash
make destroy              # or: bash scripts/destroy.sh
aws ec2 describe-nat-gateways --filter Name=state,Values=available
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId'
```

Every one of those three commands must come back empty before anyone leaves.
A forgotten NAT gateway is roughly USD 1 a day, indefinitely, and it is always
discovered a month later.

Then collect, in a shared document: the symptom each team hit, what they checked
first, and the one control they would add. That document is the actual output of
the day — better than any score.

---

## 7. Adding a challenge

1. Copy an existing file in `challenges/` and keep the header format: scenario,
   hint line, defect count. The console page and this guide both read from that
   structure.
2. Break exactly one concept per defect. Two interacting defects make a
   challenge unteachable rather than harder.
3. Write the solution file first, then break the config to match it. Doing it the
   other way round produces exercises with more than one valid answer.
4. Add the challenge to the `CHALLENGES` array in `docs/app.js` — difficulty,
   defect count, time budget, scenario and three graduated hints.
5. Do **not** add it to `terraform validate` or the scanners; `challenges/` is
   excluded from CI on purpose. A green build must never depend on the exercises
   being un-broken.
