# Epic 1 Context: Close the Bootstrap Debt

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is a brownfield, 2-year-old, solo-operator homelab. Nearly every capability in the system is already delivered and ratified as-is — this epic is the one pocket of genuinely open work. A small, closed set of bootstrap steps (OS install + GNOME tweaks, SSH key exchange, a sudoers NOPASSWD workaround, Docker registry login, GitHub key setup) has always stayed manual by deliberate choice, but today none of them carry an explicit statement of whether they're meant to stay manual forever or are on their way to being automated. This epic closes that ambiguity: every manual step gets tagged "permanently accepted" or "tracked to close." The sudoers workaround itself getting resolved and removed from the checklist is tracked directly via GitHub issue #160 on this repository — out of BMad scope, no story for it.

## Stories

- Story 1.1: Tag every manual bootstrap step with an explicit disposition

Resolving the sudoers workaround (GitHub issue #160) is out of BMad scope for this epic — it is tracked directly as a GitHub issue on this repository, not as a BMad story. Epic 1's only BMad-tracked story is 1.1.

## Requirements & Constraints

- The manual bootstrap step list is closed — nothing further is being added beyond: OS installer + GNOME tweaks, SSH key exchange, the sudoers NOPASSWD workaround, Docker registry login, GitHub key setup.
- Every item in that list must be tagged either "permanently accepted" or "tracked to close"; no item may be left untagged.
- An item tagged "tracked to close" must carry a linked GitHub issue number (the sudoers workaround → issue #160).
- Automating Docker registry login is explicitly a non-goal — it would require storing credentials somewhere, which was judged not worth the risk for a once-per-machine task. It should be tagged "permanently accepted," not "tracked to close."
- Out of BMad scope: actually resolving the sudoers workaround and closing issue #160 (removing or marking resolved the sudoers entry in the docs' manual-steps checklist) is tracked entirely on GitHub issue #160, not as a BMad story or acceptance criterion of this epic.
- Progress/success measurement stays qualitative only — do not introduce time-savings metrics or dashboards for this epic.
- All node-configuration secrets must go through Ansible Vault only, referenced directly by variable name — no plaintext, no ad hoc secret handling, if the sudoers fix touches anything secret-adjacent (unlikely, but binding if it comes up).

## Technical Decisions

- **Ansible is the default (AD-2):** anything repeatable or multi-node must be an idempotent Ansible task. Imperative one-offs are permitted only for the four named bootstrap exceptions (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup) — and each permitted exception must carry the disposition tag this epic adds. If the sudoers fix can be expressed as an idempotent Ansible task (e.g. a play that configures passwordless sudo during provisioning), that satisfies AD-2 and removes the step from the manual list entirely; it stops being a bootstrap exception once automated.
- **Manual drift tolerance (AD-3):** does not apply to AD-2's permanent bootstrap exceptions — those are permanently manual by design and governed by AD-2, not AD-3.
- **No CI enforcement exists yet (deferred/known gap):** there is no lint or CI mechanism today that distinguishes a legitimate one-off manual step from a repeatable action wrongly left manual. This epic's tagging work is discipline-enforced only; do not assume or build an automated gate as part of this epic.
- **Where the disposition tags live:** the setup-guide checklist in `docs/nodes/*/index.md` (per node-role docs), which lists the SSH key exchange, sudoers workaround, Docker registry login, and GitHub key setup entries.
- Issue #160 is the sudoers NOPASSWD workaround tracking issue; it is scoped entirely to that issue and is not itself an architecture invariant — no other architectural decision depends on how it's resolved.

## Cross-Story Dependencies

None — Epic 1 has a single story. If GitHub issue #160 closes in the future, the sudoers entry's disposition tag in the docs' manual-steps checklist should be revisited (changed from "tracked to close" to removed/resolved), but that revisit is driven by the issue's lifecycle on GitHub, not by a BMad story in this epic.
