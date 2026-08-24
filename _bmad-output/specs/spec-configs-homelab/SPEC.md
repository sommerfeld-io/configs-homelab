---
id: SPEC-configs-homelab
companions: ['glossary.md', '../../planning-artifacts/architecture/architecture-configs-homelab-2026-08-24/ARCHITECTURE-SPINE.md']
sources: ['../../planning-artifacts/prds/prd-configs-homelab-2026-08-24/prd.md']
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Homelab Configs

## Why

Manual machine setup at this homelab produces "snowflakes" — machines meant to be identical that silently diverge, discovered late and by accident (a Raspberry Pi lost NTP sync for weeks before every other Pi turned out to have the same fault; containers meant to behave identically across hosts didn't). This is both a pain to solve and a vision to realize: Sebastian, the sole operator and builder of this personal homelab fleet (3 Ubuntu workstations/servers, 5 Raspberry Pi nodes, VMs), wants every machine of a kind to install identically and be provably checkable against its declaration — disposable and rebuildable rather than hand-tuned, cattle rather than pets.

## Capabilities

- **CAP-1**
    - **intent:** Operator can provision or rebuild any node to its full declared configuration in one pass by running the playbook matching its role (desktop, server, or raspi).
    - **success:** Running the role's playbook against a freshly OS-installed node requires no manual step beyond the accepted bootstrap list (CAP-8); two nodes of the same role, provisioned from the same playbook run, converge to the same configuration.

- **CAP-2**
    - **intent:** Operator can make one node differ on purpose (e.g. an extra tool on a test server) via a dedicated host group or a playbook scoped to that machine, without changing the shared role definition.
    - **success:** The exception node's configuration diverges only in the declared way; the shared role definition used by other nodes of that role is unchanged.

- **CAP-3**
    - **intent:** Operator can check any node against its role's declared OS/security baseline on demand.
    - **success:** Running the InSpec profile matching the node's role returns pass/fail against the declared baseline.

- **CAP-4**
    - **intent:** Every node continuously reports operational telemetry, including clock/time-sync health, to Grafana Cloud, without requiring the operator to check the node manually.
    - **success:** An alertable condition (e.g. NTP desync) surfaces in Grafana Cloud without the operator manually checking that node first.

- **CAP-5**
    - **intent:** Changes to an Ansible role are exercised by an automated, multi-Ubuntu-version test matrix before ever touching a real node.
    - **success:** A role change that breaks a supported Ubuntu version fails CI before merge, rather than being discovered by provisioning a real node.

- **CAP-6**
    - **intent:** An in-progress role fix stays isolated from nodes already running the last-known-good configuration until the fix is merged.
    - **success:** Nodes already provisioned from the last-known-good configuration show no change until the fix branch is merged and its playbook is re-applied.

- **CAP-7**
    - **intent:** Docs stay structurally aligned with `ansible/playbooks/` — one doc per playbook, kept in sync when a playbook is renamed or removed.
    - **success:** Every playbook under `ansible/playbooks/` has exactly one corresponding `docs/ansible/playbooks/*.md`; renaming or removing a playbook renames or removes its doc in the same change.

- **CAP-8**
    - **intent:** Every currently-manual bootstrap step (SSH key exchange, the sudoers workaround, Docker registry login, GitHub key setup) is documented with an explicit disposition.
    - **success:** Every item in the manual-steps list is tagged either "permanently accepted" or "tracked to close"; no item is left untagged.

- **CAP-9**
    - **intent:** The sudoers NOPASSWD workaround needed on newer Ubuntu versions is resolved so it no longer appears in the manual-steps list.
    - **success:** GitHub issue #160 is closed and the docs' manual-steps list no longer includes the sudoers workaround.

## Constraints

- All node-configuration secrets go through Ansible Vault only, referenced directly by variable name in tasks — no plaintext, no ad hoc per-playbook secret handling.
- Progress/success measurement stays qualitative only — no time-savings instrumentation or dashboard is in scope for any capability above.
- Architecture invariants in `ARCHITECTURE-SPINE.md` (adopted companion, AD-1 through AD-9) are binding for all capability work — state ownership, role placement, per-machine exception mechanisms, dependency pinning, and CI scope are governed there and not restated here.

## Non-goals

- Bare-metal Pi provisioning (SD-card imaging, first-boot setup) — a distinct problem space (tools like cloudmesh-pi-burn/MAAS); this system governs from first boot onward only.
- Expanding InSpec's scope to catch the NTP-sync or cross-host Docker-consistency incidents that motivated this project — compliance stays scoped to the OS/security baseline; observability is the layer that catches those.
- Automating Docker registry login — the credential-storage risk isn't worth it for a once-per-machine task.
- Formal backup/recovery tooling beyond what exists (GitHub backs up the repo, Ansible recreates SSH keys, password login is a fallback) — the vault and sudo passwords remain one accepted, bounded risk.
- Seeking outside contributions or adoption of the public repo.
- Opening a Chef/InSpec ecosystem EOL tracking issue now — deferred until it becomes an actual problem; the real InSpec 5.x EOL runway is August 2027, longer than originally assumed.
- A dedicated maintenance-burden signal or mechanism — noticing when maintenance is getting heavy already happens naturally as part of how this project is run.

## Success signal

A node reinstalled via its role's playbook reaches full baseline compliance with no manual intervention beyond the documented accepted steps, and drift found on one node of a role is corrected fleet-wide via a single Ansible run once identified. Do not chase automating every remaining manual step just to reach "100% automated" — several are deliberately manual (e.g. Docker registry login) because automating them would introduce credential-storage risk disproportionate to the one-off task they replace.

## Open Questions

- The source PRD (FR-7's docs-mirror wording, and the Chef/InSpec Non-Goal's stated EOL date) has not yet been corrected to match the architecture spine's verified corrections reflected in this spec — update the PRD now to match, or leave the correction living only in the spine and this spec?
