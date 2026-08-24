# Epic 1 Context: Close the Bootstrap Debt

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is a brownfield, 2-year-old, solo-operator homelab. Nearly every capability in the system is already delivered and ratified as-is — this epic is the one pocket of genuinely open work. A small, closed set of bootstrap steps (OS install + GNOME tweaks, SSH key exchange, a sudoers NOPASSWD workaround, Docker registry login, GitHub key setup) has always stayed manual by deliberate choice, but today none of them carry an explicit statement of whether they're meant to stay manual forever or are on their way to being automated. This epic closes that ambiguity: every manual step gets tagged "permanently accepted" or "tracked to close," and the one step that actually should close — the sudoers workaround needed on newer Ubuntu versions — gets resolved so it can be removed from the checklist and its tracking issue closed.

## Stories

- Story 1.1: Tag every manual bootstrap step with an explicit disposition
- Story 1.2: Close the sudoers NOPASSWD workaround (issue #160)

## Requirements & Constraints

- The manual bootstrap step list is closed — nothing further is being added beyond: OS installer + GNOME tweaks, SSH key exchange, the sudoers NOPASSWD workaround, Docker registry login, GitHub key setup.
- Every item in that list must be tagged either "permanently accepted" or "tracked to close"; no item may be left untagged.
- An item tagged "tracked to close" must carry a linked GitHub issue number (the sudoers workaround → issue #160).
- Automating Docker registry login is explicitly a non-goal — it would require storing credentials somewhere, which was judged not worth the risk for a once-per-machine task. It should be tagged "permanently accepted," not "tracked to close."
- Success for the sudoers fix: provisioning a freshly OS-installed node (on an Ubuntu version affected by the NOPASSWD sudo-prompt issue) via its role's playbook requires no manual `sudo visudo` step to enable passwordless sudo for the operator's user.
- Success for issue closure: GitHub issue #160 is closed, and the docs' manual-steps checklist no longer lists the sudoers workaround as open (either removed or marked resolved).
- Progress/success measurement stays qualitative only — do not introduce time-savings metrics or dashboards for this epic.
- All node-configuration secrets must go through Ansible Vault only, referenced directly by variable name — no plaintext, no ad hoc secret handling, if the sudoers fix touches anything secret-adjacent (unlikely, but binding if it comes up).

## Technical Decisions

- **Ansible is the default (AD-2):** anything repeatable or multi-node must be an idempotent Ansible task. Imperative one-offs are permitted only for the four named bootstrap exceptions (SSH key exchange, sudoers workaround, Docker registry login, GitHub key setup) — and each permitted exception must carry the disposition tag this epic adds. If the sudoers fix can be expressed as an idempotent Ansible task (e.g. a play that configures passwordless sudo during provisioning), that satisfies AD-2 and removes the step from the manual list entirely; it stops being a bootstrap exception once automated.
- **Manual drift tolerance (AD-3):** does not apply to AD-2's permanent bootstrap exceptions — those are permanently manual by design and governed by AD-2, not AD-3.
- **No CI enforcement exists yet (deferred/known gap):** there is no lint or CI mechanism today that distinguishes a legitimate one-off manual step from a repeatable action wrongly left manual. This epic's tagging work is discipline-enforced only; do not assume or build an automated gate as part of this epic.
- **Where the disposition tags live:** the setup-guide checklist in `docs/nodes/*/index.md` (per node-role docs), which lists the SSH key exchange, sudoers workaround, Docker registry login, and GitHub key setup entries.
- Issue #160 is the sudoers NOPASSWD workaround tracking issue; it is scoped entirely to that issue and is not itself an architecture invariant — no other architectural decision depends on how it's resolved.

## Cross-Story Dependencies

- Story 1.2 (resolving the sudoers workaround) directly feeds Story 1.1's tagging: once #160 is closed, the sudoers entry in the manual-steps checklist changes from "tracked to close" to removed/resolved rather than staying open. The two stories can be worked in either order, but Story 1.1's tagging of the sudoers item is only final after Story 1.2 lands.
