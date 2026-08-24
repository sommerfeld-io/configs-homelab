- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-manual-bootstrap-disposition-tags.md`
  summary: The manual-bootstrap checklist (SSH exchange, sudoers workaround, GitHub key setup, Docker login) is duplicated verbatim between `docs/nodes/raspi/index.md` and `docs/nodes/ubuntu-workstations/index.md` with no shared source or cross-reference.
  evidence: Pre-existing structural duplication, not introduced by this change — flagged by blind-hunter review during Story 1.1. If issue #160 closes or a disposition changes, both copies need synchronized manual edits with nothing linking them to make that easy to catch.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-manual-bootstrap-disposition-tags.md`
  summary: The `ansible-roles-collection` submodule pointer is left in a dirty/uncommitted state (`ea3ab018f00e270720de6ae3ec03ba0cb1644de0-dirty`), unrelated to this docs change.
  evidence: Pre-existing since before this session started (present at the very first `git status` check) — flagged by blind-hunter review during Story 1.1. Would break `git submodule update` for anyone else if committed as-is.
