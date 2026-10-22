---
title: 'Epic 8 retro item 35: task lint validates OpenTofu without a prior init'
type: 'bugfix'
created: '2026-10-22'
status: 'done'
baseline_commit: '80b1f827782cd2fab8fa995b50ff24356c54a70c'
route: 'dispatch'
review_loop_iteration: 1
context:
    - '{project-root}/_bmad-output/implementation-artifacts/epic-8-retro-2026-10-22.md'
    - '{project-root}/_bmad-output/implementation-artifacts/spec-epic-2-retro-item-5-opentofu-pin-strategy.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Commit `63fabb4` made `task lint` run a bare `tofu validate` in both OpenTofu roots. In any checkout without `.terraform/` (a fresh clone, a new devcontainer, a worktree-isolated agent, or a provider cache that went stale after a lock bump), `task lint` fails with "required plugins are not installed". The `lint-repo` pre-commit hook runs `task lint`, so every commit is blocked. Separately, the `lint-opentofu` format check runs image `1.12.8`, while both roots and the devcontainer pin `1.12.7` (Epic 8 retro, findings R1 and R5).

**Approach:** Each `validate` task initializes its root without a backend before validating: `tofu init -backend=false -input=false -lockfile=readonly`. This needs no token and no state, and it changes neither the lock file nor the backend. The OpenTofu pins are aligned on `1.12.8`.

**Decisions (operator, 2026-10-22):**

- **Align up to `1.12.8`:** set `required_version` in both roots and the devcontainer feature to `1.12.8`, the version Dependabot already gave the `lint-opentofu` image. The devcontainer must be rebuilt afterwards. Until the rebuild, the host `tofu` (`1.12.7`) refuses both roots, so `task lint` and the pre-commit hook fail locally. CI validate derives `1.12.8` from `required_version` on its own.
- **Init only when needed (review pass 1):** a validate task first runs `tofu validate`. Only when that fails (no cache, or a cache that no longer matches the lock file) does it run the init and validate again. An initialized checkout keeps working offline, as before this change. Reason: `init -backend=false -lockfile=readonly` contacts the registry even with a populated `.terraform/`, so an unconditional init would block offline commits through the pre-commit hook.
- **No drift guard:** the Epic 2 retro item 5 decision ("no sync check between the three pins") stays. Drift can come back with the next Dependabot image bump.

## Boundaries & Constraints

**Always:**

- Use the host `tofu` from the devcontainer feature, as the other OpenTofu tasks do.
- `-lockfile=readonly`: a validate run never rewrites `.terraform.lock.hcl`.
- Keep `task cloud:digital-ocean:opentofu:validate` and `task grafana-cloud:validate` as the entry points that `task lint` calls.
- Update the docs that say "run `init` first".

**Never:**

- No change to `.github/workflows/pipeline.yml`: CI hardening is retro item 36.
- No backend initialization, token, state read or network call beyond downloading the locked providers.
- No change to the providers or the lock files. No sync check between the pins.

## I/O & Edge-Case Matrix

| Scenario                     | Input / State                                           | Expected Output / Behavior                                         | Error Handling                                       |
|------------------------------|---------------------------------------------------------|--------------------------------------------------------------------|------------------------------------------------------|
| Fresh checkout               | no `.terraform/` in either root                         | `task lint` initializes both roots and validates them (`Success!`) | N/A                                                  |
| Operator already initialized | `.terraform/` from a full `tofu init` with local state  | validate passes; local state and backend config untouched          | N/A                                                  |
| Lock bumped, cache stale     | `.terraform.lock.hcl` newer than the installed provider | init installs the locked version, and validate passes              | N/A                                                  |
| Lock file out of date        | `versions.tf` provider pin not in the lock file         | lint fails                                                         | OpenTofu's readonly-lockfile error names the problem |
| Offline, cache populated     | no network, `.terraform/` matches the lock file         | validate passes without contacting the registry                    | N/A                                                  |
| Offline, no cache            | no network, no `.terraform/`                            | lint fails                                                         | OpenTofu's registry error                            |

</frozen-after-approval>

## Code Map

- `configs-cloud/digital-ocean/opentofu/taskfile.yml:20-24` and `grafana-cloud/opentofu/taskfile.yml:19-22`: the `validate` tasks, a bare `tofu validate`. The digital-ocean `desc` says "(run init first)".
- `taskfile.yml:46-50`: `lint` calls both `validate` tasks. It stays as it is.
- `docker-compose.yml:72-77`: `lint-opentofu`, `ghcr.io/opentofu/opentofu:1.12.8`, `fmt -check`.
- `configs-cloud/digital-ocean/opentofu/versions.tf:2` and `grafana-cloud/opentofu/versions.tf:2`: `required_version = "1.12.7"`. `.devcontainer/devcontainer.json:34-36`: the feature is pinned to `1.12.7`. `docs/cloud/digital-ocean/api-token.md:51` names `1.12.7`.
- `.gitignore:20`: `.terraform/` is ignored, so the init output is never committed.
- Docs: `docs/cloud/digital-ocean/tasks-and-linters.md:24,61`; `docs/grafana-cloud/synthetic-monitoring.md:72`.
- The CI `validate-opentofu` job already runs the same init command (`pipeline.yml`). Do not touch it.

## Tasks & Acceptance

**Execution:**

- [x] `configs-cloud/digital-ocean/opentofu/taskfile.yml`: `validate` first runs `tofu validate` quietly. Only when that fails, it runs `tofu init -backend=false -input=false -lockfile=readonly`, then the final `tofu validate` reports the result. Update the comment and drop "(run init first)" from `desc`. Result: a fresh checkout validates, and an initialized checkout validates offline.
- [x] `grafana-cloud/opentofu/taskfile.yml`: the same.
- [x] Both `versions.tf`, `.devcontainer/devcontainer.json` and `api-token.md:51`: change `1.12.7` to `1.12.8`. `docker-compose.yml` already uses `1.12.8`. In the same `api-token.md` sentence, replace "`tofu init` and `plan` refuse any other version" with the observed behavior: OpenTofu does not enforce the exact pin locally; use the devcontainer; CI derives its image tag from `required_version` (review pass 1). Result: every pin names the same version, and the doc makes no false claim.
- [x] Docs at the Code Map lines: validate initializes without a backend only when needed, needs no manual `init`, and needs network access only for that first init. In `tasks-and-linters.md:61`, quote the CI init with its real flags, `-backend=false -input=false -lockfile=readonly` (review pass 1).

**Acceptance Criteria:**

- Given a copy of the repo with no `.terraform/` in either root, when `task lint` runs, then it exits 0 and `.terraform.lock.hcl` is byte-identical.
- Given an initialized root and no network, when its validate task runs, then it exits 0 without running init.
- Given an operator-initialized root with local state, when `task cloud:digital-ocean:opentofu:validate` runs, then `terraform.tfstate` and `.terraform/terraform.tfstate` are unchanged.
- Given the change, when `docker-compose.yml` and the `versions.tf` files are read, then the `lint-opentofu` image tag, both `required_version` values and the devcontainer feature all name `1.12.8`.

## Implementation Notes

Second implementation (after review pass 1), from `baseline_commit`:

- Both `validate` tasks run `tofu validate >/dev/null 2>&1 || tofu init -backend=false -input=false -lockfile=readonly`, then `tofu validate`. An initialized root runs no init (validate runs twice, both offline). The comment explains when the init runs; the digital-ocean `desc` no longer says "(run init first)". `taskfile.yml` `lint` is unchanged.
- `1.12.7` -> `1.12.8` in both `versions.tf`, `.devcontainer/devcontainer.json` and `api-token.md`. No `1.12.7` pin remains outside `_bmad-output` (`api-token.md` names `1.12.7` only as the host version observed in the `required_version` experiment). The `api-token.md` sentence now says OpenTofu does not enforce the exact pin locally, to use the devcontainer, and that CI derives its image tag from `required_version`.
- Docs: `tasks-and-linters.md` (tasks table row; validate paragraph: no manual init, init only when the cache is missing or stale, network only for that init, CI init quoted with `-input=false`) and the `synthetic-monitoring.md` tasks table (re-padded). `pipeline.yml`, providers and lock files untouched.
- Host (`tofu 1.12.7`), initialized roots: both validate tasks print `Success!` with no init output.
- AC1 on the host: both roots' `.terraform/` moved aside, `task lint` exit 0 (both validate tasks installed the locked providers, then `Success!`; all other linters passed), both lock files and both `terraform.tfstate` sha256 `OK`; the init output was discarded and the original `.terraform/` dirs moved back.
- Matrix on scratch copies of the DigitalOcean root in an unprivileged `ghcr.io/opentofu/opentofu:1.12.8` container (`docker cp`, `TF_DATA_DIR` inside the copy, no mount), running the task's commands: fresh online → init, `Success!`; offline (`--network none`) with the cache from that run → `Success!` with no init output (AC2); stale cache (providers dir moved away) → init reinstalls `v2.106.0`, `Success!`; offline without cache → exit 1 "Failed to resolve provider packages"; lock out of date (provider block removed) → exit 1 "Provider dependency changes detected", lock unchanged. Lock sha256 unchanged in every run.
- Review fixes: the init cmd has `ignore_error: true`, so the final validate always runs. Checked on a scratch copy of the Grafana root with an undeclared variable: offline (unreachable network mirror) with a populated cache, init fails, then the final validate reports "Reference to undeclared input variable"; online, the same. Offline without a cache, the final validate can only report the missing provider package, because validate needs the providers. Docs say the init runs when a first validate fails, that CI always initializes, and that the local `tofu` did not check `required_version` (rebuild the devcontainer after a pin bump).
- AC3: the DigitalOcean root has no backend block and no `.terraform/terraform.tfstate`; `terraform.tfstate` sha256 unchanged after `task lint`.

## Spec Change Log

## Review Triage Log

Review pass 1 (Blind Hunter, Edge Case Hunter, Verification Gap):

- medium, intent_gap — offline with a populated `.terraform/`: `tofu init -backend=false -lockfile=readonly` contacts the registry and fails ("Failed to resolve provider packages"; re-checked in a `--network none` `1.12.8` container after an online init, while a bare `validate` in the same state passes). Before this change, `task lint` and the pre-commit hook worked offline once initialized; the frozen matrix covers only "offline, no cache".
- medium, patch — `api-token.md:51` was edited but keeps "`tofu init` and `plan` refuse any other version"; host `tofu 1.12.7` validated a root pinning `1.99.0` (re-checked). Reword the sentence (Blind Hunter, Edge Case Hunter, Verification Gap other).
- low, patch — `tasks-and-linters.md:61` quotes the CI init as `-backend=false -lockfile=readonly`, while `pipeline.yml` runs `-backend=false -input=false -lockfile=readonly` (Edge Case Hunter, Blind Hunter).
- low, patch — the docs do not say a validate on a fresh checkout downloads providers and needs the network (Blind Hunter).
- medium, defer — CI never runs the `validate` task entry points (`validate-opentofu` inlines its own commands), so a regression in the tasks ships green; CI hardening is retro item 36 (Verification Gap).
- medium, defer — OpenTofu does not enforce the exact `required_version` locally (pre-existing, Epic 2 item 5 pin strategy); a version guard contradicts the "no drift guard" decision (Edge Case Hunter, Blind Hunter "untracked follow-up").
- low, reject — the frozen Decisions and the Verification section predict a host failure that does not happen; the fix edits this spec (Blind Hunter, Edge Case Hunter, Verification Gap other).
- low, reject — no drift reminder at the pin sites; the operator decided no drift guard (Blind Hunter).
- low, reject — no user-facing note to rebuild the devcontainer; goes in the commit body, not the code (Blind Hunter).
- low, reject — the four-line comment is duplicated in both taskfiles; two short tasks, a shared include adds structure for no named harm (Blind Hunter).
- low, reject — no `TF_PLUGIN_CACHE_DIR`; downloads take about 2 s, and the fix adds devcontainer config (Blind Hunter).
- false — "two concerns in one change": the pin bump is the operator's decision recorded in this spec, and the commit split is decided at commit time (Blind Hunter).

Review pass 2 (Blind Hunter, Edge Case Hunter, Verification Gap):

- medium, patch — any first-validate failure, including a real configuration error, takes the `||` branch; offline the init then fails and the task stops before the final `tofu validate`, so the user sees "Failed to resolve provider packages" instead of the config error (Edge Case Hunter ×3, Blind Hunter, Verification Gap other). Fix: let the task continue past a failed init so the final `tofu validate` always reports.
- low, patch — `tasks-and-linters.md` and `synthetic-monitoring.md` say the init runs "when the provider cache is missing or stale"; it runs whenever the first validate fails (Edge Case Hunter ×2).
- low, patch — `tasks-and-linters.md:61` says CI "does the same", but CI initializes unconditionally (Blind Hunter).
- low, patch — `api-token.md:51` says the "exact" pin is not enforced, but no `required_version` check happens at all (`1.99.0` passed), and it gives no rebuild hint after a pin bump (Blind Hunter ×2).
- low, patch — `deferred-work.md` ends with an extra blank line after the two new entries (Blind Hunter).
- false — "stale cache not tested with a stale cache": a scratch grafana root with `4.49.0` installed and the `4.50.0` lock fails `tofu validate` (exit 1, "there is no package for … 4.50.0 cached in .terraform/providers"), so the fallback init runs (Blind Hunter).
- false — grafana-cloud state not covered: `task grafana-cloud:validate` left `terraform.tfstate` and `terraform.tfstate.backup` sha256 unchanged (Blind Hunter).
- carried — medium, defer — CI never runs the validate task entry points; already in `deferred-work.md`, retro item 36 (Verification Gap).
- low, reject — the frozen Decisions bullet and the Code Map describe the pre-change state; the fix edits this spec (Blind Hunter ×2).
- low, reject — undocumented first-run `.terraform/` download and the silent first validate; covered by the docs' network note, no named harm (Blind Hunter).
- low, reject — the first new `deferred-work.md` entry overlaps retro item 36; existing entries are not edited (Blind Hunter).

## Design Notes

Measured on 2026-10-22 on a scratch copy of the DigitalOcean root: the first `init -backend=false -lockfile=readonly` plus `validate` took 2.0 s, and a re-run of init took 0.24 s. Without a `backend` block, `-backend=false` leaves the local backend config and the state alone. A compose service in the pinned image was considered and rejected. It would write root-owned `.terraform/` into the mount, or need a `TF_DATA_DIR` workaround, and it would download providers on every run.

## Verification

**Commands:**

- Host `tofu 1.12.7` does not enforce `required_version` (review pass 1), so the host checks below run as-is until the rebuild.
- Fresh checkout: move both roots' `.terraform/` aside (never delete), run `task lint` (expected exit 0, both lock files and `terraform.tfstate` sha256 unchanged), then move the originals back.
- Offline with cache: on a scratch copy of a root, initialize online, then run the validate task's commands in a `--network none` `ghcr.io/opentofu/opentofu:1.12.8` container (unprivileged, `TF_DATA_DIR` inside the copy, no mount of the repo). Expected: exit 0 and no init output.
- Stale cache, lock out of date and offline without cache: same scratch approach. Expected as in the matrix.

**Manual checks:**

- The operator rebuilds the devcontainer, then runs `task lint`. Expected: exit 0.
