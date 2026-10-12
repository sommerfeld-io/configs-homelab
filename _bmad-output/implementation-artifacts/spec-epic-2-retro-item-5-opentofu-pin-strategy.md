---
title: 'Decide the OpenTofu pin strategy and fix the api-token.md wording'
type: 'chore'
created: '2026-10-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `api-token.md` says OpenTofu is "the 1.12.x line" while `required_version` allows only `1.12.7`, and the unpinned host install was an open question (Epic 2 retro action item 5).

**Approach:** User decision: keep the exact pins where they are (`versions.tf`, devcontainer feature, `lint-opentofu` image). The unpinned host install in `ansible-roles-collection/packages/tasks/main/10-basics.yml` stays unpinned as a safety net; the devcontainer is the main interaction point. No sync check between the three pins (the existing deferred entry stays as is). Fix the `api-token.md` wording accordingly.

</frozen-after-approval>

## Implementation Notes

- Changed `docs/cloud/digital-ocean/api-token.md` only (Tool Versions): exact `1.12.7`, devcontainer as supported path, host install as unpinned safety net.
- Docs-only change: review layers skipped (Blind Hunter) as the change is two sentences with a decision already given by the user.
