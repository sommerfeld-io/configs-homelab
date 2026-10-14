---
title: 'Dependabot compose bumps for configs-cloud'
type: 'chore'
created: '2026-10-14'
status: 'in-progress'
route: 'oneshot'
baseline_commit: 'f5e90c5f886e97f425a13c755b0b081412e1a599'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Compose image bumps for the droplet app must arrive as Dependabot PRs that change `configs-cloud/digital-ocean`, not the retired RasPi role.

**Approach:** No code. Story 4.1 already moved the `docker-compose` entry in `.github/dependabot.yml` to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/files`. Dependabot reads its config only from the default branch, so 4.2 is the check after `digital-ocean` is merged to `main`.

- Decision (2026-10-14, user): verify after merge. No Dependabot groups and no CI for Dependabot PRs in this story.

</frozen-after-approval>

## Implementation Notes

- Findings while planning (2026-10-14):
    - The entry exists on `digital-ocean`; `main` still points at `configs-homelab/ansible/roles/raspi/fantasy-hockey/files`.
    - `sommerfeldio/fantasy-hockey:0.1.1` and `nginx:1.31.6` are the newest tags on Docker Hub, so no bump PR is pending. The first real PR comes with the next release of either image.
    - `pipeline.yml` ignores pushes to `dependabot/**`, has no `pull_request` trigger, and the Molecule jobs skip `dependabot[bot]`, so bump PRs get no CI. This predates the story and is out of scope.
- Done when:
    - `digital-ocean` is merged to `main`.
    - GitHub's Dependabot view (Insights → Dependency graph → Dependabot) lists `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey/files` and its last check succeeded, with no error for the old path.
