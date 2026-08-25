---
title: "PRFAQ Distillate: configs-homelab"
type: llm-distillate
source: "prfaq-configs-homelab.md"
created: "2026-08-24"
purpose: "Token-efficient context for downstream PRD creation"
---

## Identity

- Project/product name: "Homelab Configs" (chosen by user).
- This is the founding vision document for an existing, already-partially-implemented repo (`configs-homelab`) — not a greenfield pitch. Two years of real production use precede this PRFAQ.
- Concept type: internal/personal tool. No unit economics, no customer acquisition, no competitive moat. The customer is the sole operator (Sebastian), who is also the builder.

## Customer & problem (grounding anecdotes — user-recalled, NOT logged in-repo; `docs/incident-responses/` is empty)

- NTP/clock sync silently failed on one Raspberry Pi; discovered via a Grafana alert on that one node, later found to affect the whole fleet, fixed fleet-wide in a single Ansible run once caught.
- Docker containers meant to run identically across hosts behaved inconsistently.
- Periodic Pi-fleet repurposing historically required manual, per-node reinstall/setup.
- Core felt pain: manual setup produces "snowflakes" — machines meant to be identical silently diverge, and drift is discovered late, awkwardly, and by accident rather than by design.

## Core value proposition (rejected framing → accepted framing)

- REJECTED: a fabricated time-savings number ("X minutes vs. an afternoon") — no real measurement exists, user corrected this explicitly.
- ACCEPTED: the real benefit is consistency (every machine installs the exact same way) and disposability (machines become cheap to rebuild/discard rather than precious and hand-tuned — cattle, not pets).
- Leader-voice test: the user's own plain-spoken style rejected marketing-polished quote drafts. Accepted register: short, declarative, first-person, no flourish. Example accepted line: "Every machine should look the same after setup, every time. If I have to remember something to make that true, the automation isn't done yet."

## Scope decisions (explicit, made during Ignition — treat as settled, not open)

- OUT OF SCOPE: bare-metal Pi re-imaging / SD-card burn / first-boot provisioning. Homelab Configs governs from first boot onward only. (Distinct problem space — tools like cloudmesh-pi-burn/MAAS target it; conflating would overclaim.)
- LIMITED SCOPE, not expanding: InSpec compliance checks validate the OS/security baseline only (via dev-sec linux-baseline + org's sommerfeld-io/inspec-profiles). They do NOT and will NOT commit to catching the specific incidents that motivated the project (NTP sync, cross-host Docker consistency). Those incidents remain valid motivating history, not a coverage promise.
- Per-machine exceptions are NOT a gap — already supported via dedicated Ansible host groups or a playbook scoped to one machine.
- Docker registry login automation explicitly REJECTED — would require storing credentials somewhere (worst case, in-repo); not worth the risk for a one-off task.
- No backup/recovery tooling planned beyond what exists (GitHub backs up the repo; Ansible can recreate SSH keys; password-based node login is a fallback). Disposability-by-design is treated as the recovery strategy — accepted risk, not a gap to close.
- README's "Raspberry Pi OS or Ubuntu Server" wording for Pi nodes is INTENTIONAL, not an error — Raspberry Pi OS is deliberately kept valid for a future Pi node that needs a desktop environment, even though all current Pis run Ubuntu.

## Honest gaps (name these precisely in the PRD — do not let the press release's clean claim override this nuance)

- The founding vision's headline claim ("only manual step is the OS wizard + GNOME tweaks") is NOT fully true today. Current manual steps: SSH key exchange, a sudoers NOPASSWD workaround for newer Ubuntu (tracked: GitHub issue #160), Docker registry login, GitHub key setup. These are accepted as deliberately manual (one-off, low-cost, or credential-risk-avoiding) — not failures — but the PRD should state precisely which manual steps are permanently accepted vs. which are tracked to close (currently only #160 is tracked to close).
- Chef InSpec ecosystem risk: Chef Infra Server EOL Nov 2026, InSpec 5.x EOL Apr 2026. InSpec itself remains maintained; the surrounding ecosystem is contracting. Explicitly DEFERRED, not resolved — "needs more heat" per the verdict. Action recommended: open a tracking GitHub issue now with the EOL dates attached, rather than relying on memory to revisit "when the time comes."
- Maintenance burden of the automation itself is unmeasured, with no plan to measure it (deliberate choice). Risk: no leading indicator if maintenance cost ever exceeds the benefit. "Needs more heat" per the verdict — no action mandated, just flagged.

## Technical context (verified via artifact scan + user confirmation)

- Fleet: 3 Ubuntu workstations/servers (caprica, kobol, picon) + 5 Raspberry Pi nodes (pi4-01/02/03/05, pi5-01, all currently Ubuntu Server or Desktop) + virtual machines.
- Automated via Ansible: ~24 roles in a separate git submodule (ansible-roles-collection) covering packages, shell config, filesystem, Docker, dev tools, Grafana Alloy telemetry, repo cloning, cleanup, ClamAV, hardening, and more.
- The roles submodule runs its own CI test matrix against multiple Ubuntu versions, on every push and weekly — a real, already-operational safety net against the most likely failure mode (Ubuntu upgrades breaking role assumptions).
- Compliance: 4 InSpec profiles (desktop-baseline, server-baseline, raspi-baseline, ollama) layering dev-sec/linux-baseline (pinned) + org's own sommerfeld-io/inspec-profiles.
- Observability: Grafana Alloy agent per node, reporting to Grafana Cloud — a second, already-operational safety net alongside compliance testing. It was a Grafana alert, not manual discovery, that first caught the motivating NTP incident.
- Secrets: Ansible Vault (encrypted, safe to commit).
- Docs: MkDocs (Material theme), mirrors `ansible/` structure. Task runner: go-task.
- Git branching is itself part of the safety net: broken roles get fixed on a branch without ever touching machines running the last-known-good config.

## Strategic / sustainability signals

- Solo maintainer, no timeline pressure, no external deadline.
- Repo is public on GitHub, but outside contribution/reuse is a TOLERATED SIDE EFFECT, not a goal. README already discourages direct reuse (opinionated, will overwrite existing config).
- Real secondary motivation for public visibility (not previously stated, surfaced only in Internal FAQ): showcasing the work, with a possible payoff as a talking point in future job applications. This affects how polished/presentable the repo and docs should be, beyond pure personal utility — worth carrying into any future UX/docs-quality decisions.
- 3-year outlook: same core shape (workstations + Pi fleet + VMs), scope deliberately expanded over time as new pain points are found, #160 closed. Explicitly open-ended on which specific tools get adopted (may pick up new open-source tools along the way) but not on the operating principle: infrastructure-as-code / everything-as-code stays fixed regardless.

## Verdict summary

- Overall: solidly forged — no cracks in the foundation identified. Nearly every objection resolved into a deliberate, examined decision rather than a hand-wave, because the system already has two years of real use behind it.
- Needs more heat (carry into PRD as follow-up items, not blockers): (1) InSpec/Chef ecosystem EOL risk needs a concrete tracking issue now, not a deferred "later." (2) Maintenance-burden has no measurement or leading indicator.
- No launch blockers.

## Recommended next step

Feed this distillate + the full PRFAQ (`prfaq-configs-homelab.md`) into `bmad-prd` as the PRD's input — this PRFAQ replaces the product brief in the planning pipeline.
