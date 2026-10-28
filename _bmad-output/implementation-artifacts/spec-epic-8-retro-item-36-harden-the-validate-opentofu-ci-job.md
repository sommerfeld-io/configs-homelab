---
title: 'Harden the validate-opentofu CI job (Epic 8 retro item 36)'
type: 'chore'
created: '2026-10-28'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 8 retro findings R2-R4: the `validate-opentofu` matrix in `pipeline.yml` and the validate calls in `task lint` are hand-kept root lists ("keep in sync"), so a new OpenTofu root is never validated although the docs say "every OpenTofu root"; the job's `sed` accepts any quoted `required_version`, so a range like `~> 1.12.0` becomes an invalid image tag and an opaque Docker error; and the job logs in to Docker Hub and checks out submodules although it pulls only from `ghcr.io` and never reads a submodule.

**Approach:** One shared discovery script lists every folder with a tracked `versions.tf`; CI builds the `validate-opentofu` matrix from it and `task lint` loops over the same output. The CI step fails with a clear annotation unless `required_version` is an exact `x.y.z`. The Docker Hub login and the submodule checkout are dropped from the job. Docs follow. Implement on `main`; do not commit until the user says so.

</frozen-after-approval>

## Implementation Notes

- New `.github/workflows/assets/find-opentofu-roots.sh`: tracked `versions.tf` folders, `modules/` excluded, `LC_ALL=C sort -u`, exit 1 with a message when none; paths are relative to the repository root wherever it is called from.
- `pipeline.yml`: new `find-opentofu-roots` job (output `roots`, a JSON array from the script, assigned before the `echo` so a script failure fails the step); `validate-opentofu` `needs` it and builds its matrix with `fromJSON`; checkout without submodules; Docker Hub login removed, with a comment to add it back for a Docker Hub image; the pin must match `^[0-9]+\.[0-9]+\.[0-9]+$`, otherwise an `::error` names the value found. The workflow-level `REGISTRY` env stays: the `lint` job still uses it.
- `taskfile.yml`: new `opentofu:validate` loops over the script output with the same validate-then-init fallback as the per-root tasks; `lint` calls it instead of the two per-root validate tasks. The per-root tasks stay for single-root use.
- Docs: `tasks-and-linters.md` (paragraph and a task table row), `pipelines.md` (stage 1 lists both jobs, the stage 2 condition, the diagram), `synthetic-monitoring.md` (the `grafana-cloud:validate` row).
- Not in scope: the local `required_version` check (already in `deferred-work.md`, it would reverse the Epic 2 retro item 5 decision), the fmt lists and the lint image pin (deferred).
- Verification (2026-10-28): the script lists both roots from the root and from `docs/`; the jq output is `["configs-cloud/digital-ocean/opentofu","grafana-cloud/opentofu"]`; the pin check passes `1.12.8` and fails `~> 1.12.0`, `>= 1.12` and a missing pin; `bash -eo pipefail` exits 1 when the script fails; `task opentofu:validate` exit 0; shellcheck clean; `task lint` exit 0 (actionlint, lychee 0 errors). The workflow itself runs only after a push.
- Not committed: the user asked to implement on `main` and commit only on request.
- After review, at the user's request (2026-10-28): renamed the script to `find-opentofu-roots.sh`; removed the per-root `validate` tasks (`cloud:digital-ocean:opentofu:validate`, `grafana-cloud:validate`) so `task opentofu:validate` is the only validate task and the validate-then-init logic exists once (resolves finding 4). Their comment moved to the root task; `dns-zone.md` step 2, the `tasks-and-linters.md` table and paragraph, and the `synthetic-monitoring.md` table name `task opentofu:validate`. `task lint` exit 0 afterwards.

## Review Triage Log

Blind hunter, one pass (floor N = 4, 12 findings).

| #  | Finding                                                        | Verdict | Route  | Evidence                                                                                                                  |
|----|----------------------------------------------------------------|---------|--------|---------------------------------------------------------------------------------------------------------------------------|
| 1  | `echo "roots=$(...)"` hides a failing script                   | medium  | patch  | The status of a substitution inside `echo` arguments is lost; now assigned first, `bash -eo pipefail` exits 1             |
| 2  | Child modules with a `versions.tf` would count as roots         | low     | patch  | No module today; one pathspec `:(glob,exclude)**/modules/**` and a header note                                            |
| 3  | Formatting still uses hand-kept lists                          | medium  | defer  | Outside R2 (validate lists); `deferred-work.md`                                                                            |
| 4  | Init fallback exists in three tasks                            | low     | reject | Two lines each; making the per-root tasks call the loop adds indirection for a rare drift                                  |
| 5  | Whitespace in root paths, `sh:` var failure                    | low     | reject | Repository folders are kebab-case (ls-lint); a failing `sh:` var already stops the task with the script's stderr           |
| 6  | No local `required_version` check                              | low     | reject | Already a `deferred-work.md` entry tied to the Epic 2 retro item 5 decision; the docs say the CI job enforces it            |
| 7  | Stale docs: `synthetic-monitoring.md`, task table, `api-token.md` | medium | patch (part) | First two caused by this change, fixed; the `api-token.md` image claim predates it, deferred                       |
| 8  | `pipelines.md` missing comma, diagram omits the new job        | low     | patch  | Both one-word fixes                                                                                                        |
| 9  | `sed` misses tabs, joins multiple matches                      | low     | reject | `tofu fmt` (enforced by `task lint` and CI) writes spaces; a commented line starts with `#` and does not match `^ *`        |
| 10 | Script untested, locale sort, whitespace in `dirname`          | low     | patch (part) | `LC_ALL=C` added; shellcheck covers the file once tracked; whitespace as in 5                                     |
| 11 | Spec in progress without notes or verification                 | false   | reject | Finalized at the end of the workflow; notes and verification above                                                         |
| 12 | No note on the dropped Docker Hub login                        | low     | patch  | One comment line in the job                                                                                               |
