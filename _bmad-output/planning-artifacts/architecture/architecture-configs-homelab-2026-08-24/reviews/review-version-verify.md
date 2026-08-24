# Reviewer Gate — Version Verification

**Lens:** every committed decision was web-researched or reality-checked
**Target:** `ARCHITECTURE-SPINE.md` Stack table (7 entries)
**Reviewer date:** 2026-08-24
**Verdict:** PASS — no red flags requiring a spine change. One correction recommended for the *PRD* text (not this spine), detailed below.

---

## Skipped (not publicly checkable, as instructed)

| Entry | Why skipped |
| --- | --- |
| `ansible-roles-collection` submodule, `v0.15.0` | Private/org git submodule — version is a repo-local pin against the operator's own history, not a public package with an independent release feed to verify against. |
| InSpec profile spec version `0.92.1` | An internal versioning scheme this repo applies to its own four InSpec profiles (bumped together) — not a published package version, nothing external to check it against. |

## Best-effort (private-ish repo)

**`sommerfeld-io/inspec-profiles`, branch `main`**
Confirmed reachable and public via the GitHub API: `https://api.github.com/repos/sommerfeld-io/inspec-profiles` returns `"private": false`, `"default_branch": "main"`, `"archived": false`, `"disabled": false`, with `pushed_at: 2026-08-24T11:18:19Z` (pushed to today) — actively maintained, branch name matches the spine's stated intentional float. No further external verification applicable (it's the operator's own repo, per AD-7).
Source: `https://api.github.com/repos/sommerfeld-io/inspec-profiles` (fetched 2026-08-24).

---

## Checked: 4 of 4 publicly checkable technologies

### 1. InSpec CI runner image — `chef/inspec:5.22.76`

- **Exists:** confirmed. Docker Hub lists tag `5.22.76` under `chef/inspec` (pushed ~1 year ago, 180.3 MB). GitHub `inspec/inspec` releases history includes the surrounding 5.22.x line (v5.22.72, v5.22.80, v5.22.95, etc.).
  Sources: Docker Hub tags listing for `chef/inspec`; `https://github.com/inspec/inspec/releases`.
- **Maintained:** yes. The `inspec/inspec` GitHub repo shows releases continuing well past this pin — latest observed release `v5.24.24` (2026-06-25) — across v5.x, v6.x and v7.x branches, with active PR merges. Not abandoned or archived.
  Source: `https://github.com/inspec/inspec/releases`.
- **Materially newer version / EOL check:** Chef's own canonical support-matrix file (`chef/chef-web-docs`, `content/versions.md`, **last updated 2026-08-24 — today**) states:
    - InSpec **7.x**: GA (current), no deprecation/EOL date.
    - InSpec **5.x and 6.x**: **Deprecated**, EOL **2027-08-31**.
    - InSpec **4.x and earlier**: EOL as of 2026-07-31.

  So the pinned `5.22.76` line is in the "Deprecated" tier (a newer major, v7, exists) but is **not yet EOL** — it has just over a year of runway left (through Aug 2027) and is still receiving security fixes. This is a routine "there's a newer major version" situation, not a red flag per the review's own instruction (flag only EOL/vuln/abandonment, not "newer version exists").
  Source (authoritative, same-day): `https://raw.githubusercontent.com/chef/chef-web-docs/main/content/versions.md`, commit `166623f` dated 2026-08-24T10:39:17Z.

  **Note on a conflicting secondary source:** the community-maintained `endoflife.date/chef-inspec` page states InSpec major-version-5's "security support" ended 2025-10-16, which if taken at face value would mean the pin is already past EOL. Cross-checking against Chef's own canonical `versions.md` (fetched same day, freshest possible source) shows this is **stale/inaccurate** — Chef's current official policy for the 5.x/6.x tier is "Deprecated, EOL 2027-08-31," not already-EOL. **Chef's own doc is treated as authoritative here** since it is first-party and dated the same day as this review.
  Source: `https://endoflife.date/chef-inspec` (community source, shown for completeness but not used as the deciding source).

- **Verdict:** no red flag. Version is real, project active, not EOL (deprecated tier, ~1 year of runway remaining).

### 2. `dev-sec/linux-baseline` pinned to tag `2.9.0`

- **Exists:** confirmed. GitHub release tag `2.9.0` exists (dated 2024-08-21).
  Source: `https://github.com/dev-sec/linux-baseline/releases/tag/2.9.0`.
- **Maintained:** yes. Latest release is `2.10.0`. Recent release notes include active work (ptrace-attach restriction hardening, IPv6 sysctl additions, InSpec-compatibility updates), 14 open issues / 6 open PRs — normal activity level for a small, focused security-baseline project. Not archived, not abandoned.
  Source: `https://github.com/dev-sec/linux-baseline/releases`.
- **Materially newer version:** `2.10.0` exists vs. pinned `2.9.0` — a minor bump, no EOL/advisory attached. Per review scope, not a reason to flag (only newer *major* version / EOL / vuln triggers a flag).
- **DevSec project overall still active?** Yes — the `dev-sec` GitHub org continues to publish and update multiple InSpec baseline profiles (`linux-baseline`, `ssh-baseline`, `nginx-baseline`, `linux-patch-baseline`, etc.) with ongoing releases into 2026. No indication of the org being archived or abandoned.
  Source: `https://github.com/orgs/dev-sec/repositories`; `https://github.com/dev-sec/linux-baseline`.
- **Verdict:** no red flag.

### 3. `ansible-lint` CI image, pinned `0.79.33`

- **Important clarification found during verification:** this pin is **not** the upstream `ansible/ansible-lint` PyPI package's own version (that project is on calendar-versioned releases like `26.6.0` as of mid-2026 — it never had a `0.79.x` line). The repo's `docker-compose.yml` (line 66) actually pulls **`pipelinecomponents/ansible-lint:0.79.33`** — a third-party wrapper/CI image maintained by the `pipeline-components` project (mirror of `gitlab.com/pipeline-components/ansible-lint`), whose own tag numbering is independent of the wrapped tool's version.
  Source: repo file `/workspaces/configs-homelab/docker-compose.yml` line 66; `https://github.com/pipeline-components/ansible-lint`.
- **Exists:** confirmed. Docker Hub lists tag `0.79.33` for `pipelinecomponents/ansible-lint` (pushed ~3 months ago, 115.51 MB, `linux/amd64` + `linux/arm64`).
  Source: Docker Hub tags listing for `pipelinecomponents/ansible-lint` filtered on `0.79`.
- **Maintained:** yes, but in "automated dependency-bump" mode rather than active feature development — tags `0.79.29` through `0.79.38` all exist and were pushed in the same short window (~3 months ago), consistent with an automated pipeline that bumps the wrapper image whenever its bundled `ansible-lint`/`ansible` dependency updates. Not abandoned; this is the expected steady-state for this kind of wrapper image.
- **Materially newer version:** `0.79.38` is the newest observed 0.79.x tag — a patch-level difference from the pinned `0.79.33`, no major-version gap, no EOL/advisory found against either the wrapper image or the upstream `ansible-lint` tool it bundles.
- **Verdict:** no red flag. Recommend the spine's Stack table (or a footnote) clarify that this entry is the `pipelinecomponents/ansible-lint` wrapper image tag, not the upstream `ansible-lint` package version, to avoid future confusion — this is a documentation-clarity note, not a version-currency problem.

### 4. go-task (Taskfile schema) `3.42.1`

- **Exists:** confirmed. GitHub release `v3.42.1` exists for `go-task/task`, dated 2026-03-10 (fixed a type-error bug in global variables, #2106/#2107).
  Source: `https://github.com/go-task/task/releases/tag/v3.42.1`.
- **Maintained:** yes, clearly active. As of this review the release page itself notes 614 commits to `main` since that release, and newer releases (e.g. `v3.45.3`, `v3.43.1`) were found in the same search pass — continuous point-release cadence.
  Sources: `https://github.com/go-task/task/releases/tag/v3.42.1`; `https://github.com/go-task/task/releases/tag/v3.45.3`; `https://github.com/go-task/task/releases/tag/v3.43.1`.
- **Materially newer version:** newer 3.4x.x patch/minor releases exist, but go-task has had no major-version (v4) jump, no EOL notice, no advisory found. Ordinary ongoing maintenance.
- **Verdict:** no red flag.

---

## Fact-check: PRD's "Chef/InSpec ecosystem EOL risk" (Deferred item in the spine)

The spine defers this exactly as: *"Chef/InSpec ecosystem EOL risk (Chef Infra Server Nov 2026, InSpec 5.x Apr 2026) — already deferred in the PRD (Non-Goals); not re-litigated here."*

Checked against Chef's own canonical, same-day-updated support matrix (`chef/chef-web-docs/content/versions.md`, commit dated 2026-08-24):

| Component | PRD's stated date | Chef's official current status (as of today) | Assessment |
| --- | --- | --- | --- |
| Chef Infra Server | Nov 2026 | 15.x: Deprecated, **EOL 2026-11-30** | **Accurate** — matches almost exactly. Not yet EOL, ~3 months of runway from today. |
| InSpec 5.x | Apr 2026 | 5.x/6.x: Deprecated, **EOL 2027-08-31** | **PRD's date does not match the official schedule.** The real EOL for the 5.x line is over a year later than the PRD states (Aug 2027, not Apr 2026) — i.e. the actual runway is *longer*, not shorter, than the PRD assumed. |

**Net finding:** the risk is real (both components are on a deprecation track) but **not worse than understood** — if anything the InSpec side has *more* runway than the PRD's "Apr 2026" figure implied, and neither component is already fully EOL'd today. This confirms the PRD's decision to defer the risk was reasonable and, if anything, conservative. No action required on this spine; flagging the InSpec date discrepancy only so a future PRD refresh can correct "Apr 2026" → "Aug 2027" if it re-touches that section.

Sources:
- `https://raw.githubusercontent.com/chef/chef-web-docs/main/content/versions.md` (commit `166623f`, 2026-08-24T10:39:17Z) — primary/authoritative.
- `https://ciq.com/blog/chef-infra-server-eol-options` — third-party corroboration of the Chef Infra Server Nov 2026 date ("no new code, features, or security fixes contributed to the open-source server after the end of October 2026").
- `https://endoflife.date/chef-inspec` — community source; found to disagree with Chef's own doc (states InSpec-5 security support already ended 2025-10-16). Chef's first-party, same-day-dated `versions.md` was treated as authoritative over this community page.

---

## Summary

- **4 of 4** publicly checkable stack entries verified: `chef/inspec:5.22.76`, `dev-sec/linux-baseline:2.9.0`, `pipelinecomponents/ansible-lint:0.79.33` (the actual image behind the spine's "`ansible-lint`" entry), `go-task v3.42.1`.
- **Red flags found: none.** All four versions are real, all four projects are actively maintained, no EOL/advisory/abandonment against any pinned version.
- **2 entries correctly skipped** as instructed (private submodule pin, internal profile-spec version).
- **1 entry best-effort verified** (`sommerfeld-io/inspec-profiles`) — reachable, public, active, matches the spine's stated branch.
- **2 documentation notes** (non-blocking, no spine change required):
    1. The spine's "`ansible-lint` (CI image)" Stack entry is actually the `pipelinecomponents/ansible-lint` wrapper image, not the upstream `ansible/ansible-lint` package — worth a one-line clarification if the spine is revised for other reasons.
    2. The PRD's deferred-risk note gives InSpec 5.x's EOL as "Apr 2026"; Chef's own current schedule gives 2027-08-31. Not urgent, but worth correcting on a future PRD touch.
