---
title: 'environment=homelab label in the homelab Alloy config'
type: 'feature'
created: '2026-10-13'
status: 'done'
baseline_commit: 'b696a0a1966a6d704c08aa154b485974fb5deffc'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Homelab series in Grafana Cloud carry no `environment` label, so they cannot be told apart from the DigitalOcean droplet, which carries `environment=digital-ocean` (CAP-4, Story 3.3).

**Approach:** In `configs-homelab/ansible/roles/grafana-cloud/alloy/templates/config.alloy.j2` add `environment = "homelab"` as an `external_labels` entry of `prometheus.remote_write "metrics_service"` and `loki.write "grafana_cloud_loki"`, the same mechanism the cloud config uses, so every series and log line leaving a node carries it. The existing `source` label and everything else in the template stay unchanged. Describe the label in the role README (copied to `docs/ansible/roles/grafana-cloud/alloy.md` by `task docs:generate`). No `stage` label on the homelab (AD-10).

</frozen-after-approval>

## Implementation Notes

Added `environment = "homelab"` to `external_labels` of `prometheus.remote_write "metrics_service"` and `loki.write "grafana_cloud_loki"` in the fleet template, plus a Labels section in the role README (copied to `docs/ansible/roles/grafana-cloud/alloy.md` by `task docs:generate`). The `source` label is not defined anywhere in this repo (not in the template), so it is untouched. `lint-alloy-config` validates the template.

## Review Triage Log

- false: `external_labels` lose to a pipeline-set `environment` label (blind). Nothing in the fleet template or exporters sets `environment` (grep), so the label always applies.
- false: docs copy may be hand-edited, and a config change may not restart Alloy (blind). `docs/ansible/roles/grafana-cloud/alloy.md` comes from `task docs:generate` (run by `task lint`); the fleet role always ends with a forced Alloy restart.
- false: nothing validates the template syntax (blind). `lint-alloy-config` ran `alloy validate` and passed.
- low (rejected): `homelab` hardcoded twice instead of a role variable (blind). The label is a literal by design (AD-10); a variable adds surface for no second consumer.
- low (rejected): new `environment` label may split existing series for label-selecting dashboards or alerts (blind). Queries without the label keep matching; the story asks for the label.
- low (rejected): README wording, link instead of inline path, why the homelab has no `stage` (blind). Cosmetic.
- low (rejected): no rendered-config assertion (blind). Same gap as the one already deferred from Story 3.2.

## Review Findings

- [x] [Review][Decision] Droplet series are briefly labeled `environment=homelab` on every provision run — resolved by the user: fix now. The label comes from the role variable `alloy_environment` (default `homelab`); the DigitalOcean inventory already sets `digital-ocean`; AD-10 and `epic-3-context.md` updated. The fleet `alloy` role writes the fleet `config.alloy.j2` (now with `environment="homelab"`) and restarts Alloy on the droplet before the cloud `alloy-config` role replaces it (Story 3.2 design). Before 3.3 that window shipped unlabeled series; now it ships droplet series as `environment=homelab` for a few seconds per run, which leaks into homelab-filtered dashboards (edge-case).
- [x] [Review][Patch] `docs/cloud/digital-ocean` not updated for the homelab label [docs/cloud/digital-ocean/provisioning.md:42] — the epic rule says every story updates these docs; "Alloy and Labels" should say homelab series carry `environment=homelab` and no `stage`, and how to filter one from the other (acceptance-auditor).
