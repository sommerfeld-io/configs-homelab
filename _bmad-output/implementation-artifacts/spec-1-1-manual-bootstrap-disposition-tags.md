---
title: 'Tag manual bootstrap steps with explicit disposition'
type: 'chore'
created: '2026-08-24'
status: 'done'
route: 'one-shot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The manual bootstrap checklist (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup) in the node setup docs gave no indication of which items are permanently manual by design versus tracked to eventually close.

**Approach:** Add an explicit `_Disposition: permanently accepted_` or `_Disposition: tracked to close_` tag to each of the four items in both node setup guides, with a short legend explaining the convention and its scope.

</frozen-after-approval>

## Suggested Review Order

**Legend / convention**

- Explains what disposition tags mean and that they're scoped to only the four automation-boundary steps
  [`ubuntu-workstations/index.md:11`](../../docs/nodes/ubuntu-workstations/index.md#L11)
- Same legend, Raspberry Pi setup guide
  [`raspi/index.md:41`](../../docs/nodes/raspi/index.md#L41)

**Disposition tags — Ubuntu workstations**

- SSH key exchange tagged permanently accepted
  [`ubuntu-workstations/index.md:32`](../../docs/nodes/ubuntu-workstations/index.md#L32)
- Sudoers NOPASSWD workaround tagged tracked to close (issue #160 already linked inline)
  [`ubuntu-workstations/index.md:44`](../../docs/nodes/ubuntu-workstations/index.md#L44)
- GitHub deploy-key setup tagged permanently accepted
  [`ubuntu-workstations/index.md:49`](../../docs/nodes/ubuntu-workstations/index.md#L49)
- Docker registry login tagged permanently accepted
  [`ubuntu-workstations/index.md:50`](../../docs/nodes/ubuntu-workstations/index.md#L50)

**Disposition tags — Raspberry Pi nodes**

- SSH key exchange tagged permanently accepted
  [`raspi/index.md:50`](../../docs/nodes/raspi/index.md#L50)
- Sudoers NOPASSWD workaround tagged tracked to close
  [`raspi/index.md:51`](../../docs/nodes/raspi/index.md#L51)
- GitHub deploy-key setup tagged permanently accepted
  [`raspi/index.md:56`](../../docs/nodes/raspi/index.md#L56)
- Docker registry login tagged permanently accepted
  [`raspi/index.md:57`](../../docs/nodes/raspi/index.md#L57)
