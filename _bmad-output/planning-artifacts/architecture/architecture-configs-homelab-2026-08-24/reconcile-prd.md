# Reconciliation: ARCHITECTURE-SPINE.md vs prd.md

## Input

- `prd.md` (`/workspaces/configs-homelab/_bmad-output/planning-artifacts/prds/prd-configs-homelab-2026-08-24/prd.md`)

## Gaps or Contradictions Found

Ranked by importance. Two real findings; one minor completeness note. The known AD-9/FR-7 divergence is explicitly excluded per instructions (already logged as a Deferred item).

### 1. FR-8's actual testable requirement (doc-tagging discipline) has no governing invariant — Capability Map mapping is misleading (Medium)

The Capability → Architecture Map lists FR-8 ("Manual steps documented, not hidden") as governed by **AD-2**. But FR-8's testable consequence is specifically:

> Every item in the manual-steps list (§4.6) is tagged either "permanently accepted" or "tracked to close"; no item is left untagged.

AD-2 only establishes *which* actions are permitted as one-time manual exceptions (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup) — it says nothing about a documentation obligation to tag each one's disposition. No other AD in the spine establishes a "manual steps must be enumerated and tagged in docs" rule either. A future builder consulting the map for "what governs FR-8" will find AD-2 and see only the *permitted-exception* rule, not the *documentation-completeness* rule the FR is actually about. This is a silent drop of a quality bar the PRD treats as load-bearing (it's a full Feature section, 4.6, with its own testable consequence and closed/confirmed status).

**Recommendation:** Either add a thin invariant (or extend AD-2) stating that each permitted manual-bootstrap exception must be recorded in project docs with an explicit permanently-accepted/tracked-to-close disposition, or explicitly note in Deferred that FR-8's tagging discipline is a docs-content requirement intentionally left ungoverned by architecture (a defensible call, but currently unstated).

### 2. AD-3's scope doesn't explicitly exclude the AD-2 bootstrap exceptions — risk of misreading as "eventually automate everything manual" (Medium-low)

AD-3 states: "a manual change made directly on a node is acceptable as transient/debugging state. Before it's 'done,' it must be captured in the Ansible declaration and re-applied... Applies uniformly across workstations, servers, and Pi nodes."

Read literally and in isolation, this could be interpreted as applying to *all* manual on-node changes, including the four AD-2 bootstrap exceptions (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup). But the PRD is explicit that some of these are **permanently** manual by deliberate decision — most pointedly, "Automating Docker registry login" is a named Non-Goal (§5), rejected because it would require storing credentials somewhere, and FR-8 explicitly distinguishes "permanently accepted" items from "tracked to close" ones (only the sudoers workaround, via FR-9, is meant to ever be closed out).

AD-3 and AD-2 are clearly meant to describe two different categories of "manual" (AD-3 = ad hoc debugging/drift fixes that should be captured; AD-2 = a fixed, deliberately-permanent set of bootstrap actions that are *not* meant to be captured into Ansible), but the spine text never draws this boundary explicitly. A future builder could read AD-3's "applies uniformly" language as overriding AD-2's permanent exceptions and push to automate Docker registry login "to finish the job" — directly contradicting an explicit, confirmed PRD Non-Goal.

**Recommendation:** Add a one-line carve-out to AD-3 (e.g., "Does not apply to the AD-2 bootstrap exceptions, which are permanently manual by design — see FR-8/§4.6") to remove the ambiguity.

### 3. Structural Seed / inventory groups don't mention where VMs fit (Low, informational only)

The PRD's Vision, Glossary ("Fleet"), and JTBD all explicitly count VMs as nodes ("Every workstation, Raspberry Pi, and VM in the fleet..."). The spine's Structural Seed and inventory-groups diagram list only `ubuntu_desktop`, `ubuntu_server`, `raspi`, and `ollama` — no mention of VMs or how they map onto AD-5's three exception mechanisms or the desktop/server/raspi role groups. This isn't a contradiction (a VM presumably just gets inventoried under whichever node-role group matches its OS, same as any physical machine), but it's an omission a future builder extending the fleet with a new VM might trip over, since the spine never says so. Not significant enough to rank higher — no PRD claim is contradicted, and "VM" isn't a distinct node role in the PRD's own glossary.

## Anything Verified as Fine (brief)

- **All FR-1 through FR-9** are present in the Capability → Architecture Map; none are missing.
- **FR-7 vs AD-9** — known, deliberate correction, already logged in Deferred. Not re-reported here per instructions.
- **PRD §4.2/§4.3 (InSpec vs. Alloy scope) vs. spine's dual-verification paradigm** — consistent. Spine's "InSpec (static OS/security baseline, pass/fail on demand)" / "Alloy (live telemetry, catches what a static baseline can't)" framing matches the PRD's "compliance stays honestly scoped to the OS/security baseline; observability is the layer that actually caught the NTP incident" almost verbatim in spirit.
- **Non-Goal: Expanding InSpec's scope** — not contradicted; spine never implies InSpec should/does catch NTP or cross-host Docker drift.
- **Non-Goal: Automating Docker registry login** — not contradicted at the AD-2 level (it's correctly listed as a permitted, narrow manual exception); see Finding 2 above for the adjacent AD-3 ambiguity.
- **Non-Goal: Formal backup/recovery tooling** — spine asserts nothing implying formal backup/recovery exists or is required (AD-1's "no separate state store" is about state ownership, not backup/recovery).
- **Non-Goal: Seeking outside contribution/adoption** — not addressed or contradicted by the spine (correctly out of scope).
- **Non-Goal: Chef/InSpec EOL risk** and **Non-Goal: maintenance-burden signal** — both explicitly carried into the spine's Deferred section, correctly not re-litigated.
- **Qualitative-only Success Metrics stance (§7)** — the spine introduces no invariant, stack entry, or structural element implying quantitative measurement infrastructure; nothing in the spine would push toward or require it.
- **SM-1 achievability** — AD-2's narrow bootstrap-exception list matches SM-1's "no manual intervention beyond §4.6 accepted steps" criterion; nothing in the spine blocks this.
- **SM-2 achievability** — AD-1 (single source of truth) + AD-4 (role placement) support "fix once, applies fleet-wide via one Ansible run"; nothing in the spine blocks this.
- **FR-2's Out-of-Scope (ad-hoc undocumented manual changes reintroduce snowflaking) vs. AD-3** — consistent: AD-3 only tolerates manual drift as *transient*, requiring eventual capture into the Ansible declaration before it's "done," which matches the PRD's concern about permanently undocumented changes.
- **FR-2's feature-specific NFR (secrets via Ansible Vault only)** — fully covered by AD-6, including the "no plaintext" and "one sanctioned edit path" details.
