---
title: 'Epic 7 retro item 25: enforce the dev/test/prod stage list and derive the playbook stage like the inventory'
type: 'chore'
created: '2026-10-16'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Epic 7 retro (`epic-7-retro-2026-10-15.md`, findings 11 and 12, action 2 = sprint action item 25) found that `docs/cloud/domain-naming.md` says "No other stages are allowed", but `stage` in `configs-cloud/digital-ocean/opentofu/droplets.tf` is free text, documented only in a comment. A stage such as `pre-prod` passes `tofu apply` and derives a wrong domain. The stage is also derived from the droplet name twice, with different expressions: the inventory's `alloy_stage: do_name.split('-')[0]` and `deploy-fantasy-hockey.yml`'s `inventory_hostname.split('-', 1) | first`.

**Approach:** Make `tofu plan` fail for any droplet whose `stage` is not `dev`, `test` or `prod`, with a `lifecycle` `precondition` on `digitalocean_droplet.this` (`locals` cannot carry a `validation` block). The playbook takes the stage from the inventory's `alloy_stage`, so the inventory is the single place the stage is derived. Update the docs that state the rule (`domain-naming.md`, `droplet.md`, `deployment.md`, the playbook page). No resource changes: the plan for the current `droplets` map stays `No changes.`

</frozen-after-approval>

## Implementation Notes

- `droplets.tf`: `local.stages = ["dev", "test", "prod"]` and a `lifecycle` `precondition` on `digitalocean_droplet.this`. The retro said "OpenTofu `validation`"; `locals` cannot carry one, and the map is not a variable, so a precondition does the same job at plan time.
- Proof (read-only plans, token present): current map → `No changes.` (exit 0). A temporary `dummy` entry with `stage = "staging"` → `Error: Resource precondition failed … Droplet "dummy" has stage "staging", but the stage must be one of dev, test, prod`; the same entry with `test` → `Plan: 1 to add, 1 to change`. Restored afterwards; the final plan is `No changes.` again.
- Renaming the stage of the existing droplet to `pre-prod` stops earlier, at the volume's `prevent_destroy` (the name change would replace it), so that path was already blocked.
- `deploy-fantasy-hockey.yml`: `fantasy_hockey_domain` takes the stage from `alloy_stage`. `ansible -i inventory prod-fantasy-hockey -m debug` with the new expression renders `fantasy-hockey.prod.do.sommerfeld.app`, as before.
- Docs: `domain-naming.md`, `droplet.md` (section and options row), `deployment.md`, `provisioning.md`, the playbook page, plus the inventory comment saying the domain depends on `alloy_stage`.
- `tofu fmt -check`, `tofu validate`, `task lint` pass.

## Review Triage Log

Blind Hunter, one pass (floor N = 4, 11 findings).

| #  | Finding                                                                            | Verdict | Route  | Evidence                                                                                                                                                       |
|----|------------------------------------------------------------------------------------|---------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | Spec unfinished (status, empty notes, no triage log)                               | false   | reject | The oneshot route fills these at finalize                                                                                                                      |
| 2  | No evidence for "No changes." or the failing plan                                  | false   | reject | Both plans ran before the review; now recorded above                                                                                                           |
| 3  | The new domain expression is untested                                              | false   | reject | Rendered against the live inventory with `ansible -m debug`; recorded above                                                                                    |
| 4  | No assert that `alloy_stage` is defined and in the list                            | low     | reject | An undefined variable already fails the play loudly; a console droplet with a wrong stage gets a domain the DNS guard rejects before Caddy starts              |
| 5  | The domain depends on a monitoring variable                                        | low     | patch  | A neutral variable would mean a second copy of the expression; kept the one `alloy_stage`, and the inventory comment now says a change also changes the domain |
| 6  | "Derived in one place only" is half true: the app key is still split from the name | low     | patch  | Comment reworded: the stage comes from `alloy_stage`, the app is the rest after the first hyphen                                                               |
| 7  | `-target` plans on a volume or reserved IP skip the droplet precondition           | low     | reject | Any untargeted plan still fails; targeted plans are a rare manual path                                                                                         |
| 8  | The `droplet.md` options row does not mention the enforcement                      | low     | patch  | Row now says any other value fails `tofu plan`                                                                                                                 |
| 9  | `provisioning.md` and the inventory comment describe `alloy_stage` only as a label | low     | patch  | Both now say the deploy builds the domain from it                                                                                                              |
| 10 | A playbook comment line is 107 characters                                          | low     | patch  | Paragraph re-wrapped                                                                                                                                           |
| 11 | Sprint item still `open`; its text says "validation"                               | low     | patch  | Closed with this change; the precondition-vs-validation choice is in the notes                                                                                 |
