---
title: 'Verify the DigitalOcean token scopes and update api-token.md'
type: 'chore'
created: '2026-10-12'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The scope table in `docs/cloud/digital-ocean/api-token.md` has no `tag` scope although the droplet is created with `tags`, and grants `ssh_key` full CRUD although only a data source reads it (Epic 2 retro action item 6).

**Approach:** Check the scopes against the DigitalOcean API scope docs, add `tag` (create, read), trim `ssh_key` to read, and list the required read scopes of `droplet:create`.

</frozen-after-approval>

## Implementation Notes

- Verified against docs.digitalocean.com (scopes index and `droplet:create`): tagging at creation needs `tag:create` (optional "associated" scope), which needs `tag:read`; `droplet:create` requires `droplet`, `regions`, `sizes`, `actions`, `image`, `snapshot`, `vpc` read.
- Changed `docs/cloud/digital-ocean/api-token.md` only; table got a Permissions column.
- Not verified: the live token's scopes and the minimal permissions of `block_storage`, `reserved_ip`, `project` (needs the control panel); the docs now say so.
