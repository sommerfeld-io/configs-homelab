---
title: "PRFAQ: Homelab Configs"
status: "complete"
created: "2026-08-24"
updated: "2026-08-24"
stage: "complete"
inputs:
  - "/workspaces/configs-homelab/README.md"
  - "/workspaces/configs-homelab/docs/index.md"
  - "/workspaces/configs-homelab/docs/nodes/raspi/index.md"
  - "/workspaces/configs-homelab/docs/nodes/ubuntu-workstations/index.md"
  - "/workspaces/configs-homelab/docs/ansible/playbooks/"
  - "/workspaces/configs-homelab/tests/inspec/"
  - "web research: homelab IaC / config-drift landscape, 2026"
---

# Homelab Configs Makes Every Machine in a Personal Server Fleet Provably Identical

## One operator's Ansible-driven setup replaces manual reinstalls and silent configuration drift with a single source of truth every machine can be checked against

Today, Homelab Configs formalizes something that has quietly been running for two years: every physical workstation, virtual machine, and Raspberry Pi in this homelab is now defined, provisioned, and verified as code — not configured by hand and hoped to match its siblings. For an operator running a mixed fleet solo, that means one thing above all: a machine is either running its declared setup, or the automation says so. Not "probably." Not "I think so."

Setting up a machine used to mean remembering every step by hand — which packages, which shell config, which Docker version, which hardening rules — every time, from memory. Something always got missed, or done slightly differently than last time. Machines meant to be twins quietly became strangers. The gap rarely showed up right away. It surfaced later, awkwardly: a container behaving differently on one host than another that was supposed to be its match — or, memorably, a Raspberry Pi silently losing time sync for weeks before anyone noticed, and by the time it was noticed, every other Pi in the rack had the same problem, invisibly.

Homelab Configs changes what "setting up a machine" means. After the OS installer finishes and a light pass of GNOME tweaks, one playbook installs everything else — packages, dev tools, containers, hardening, monitoring — the exact same way, every time, on every machine of its kind. That consistency turns machines from hand-tuned originals into disposable, rebuildable units: if a workstation misbehaves, or an experiment calls for wiping one clean, rebuilding it from the same definition costs a command, not an afternoon of memory. And because the same definitions are continuously checked against what's actually running, the operator doesn't have to hope machines stayed in line — they can ask, and get a straight answer.

> "Every machine should look the same after setup, every time. If I have to remember something to make that true, the automation isn't done yet."
> — Sebastian, Creator & Operator, Homelab Configs

### How It Works

1. Install the OS — Ubuntu Desktop or Server — using the standard installer. Nothing homelab-specific yet.
2. Point Homelab Configs at the new machine and run the playbook matching its role (desktop, server, or raspi). Packages, shell setup, dev tooling, containers, hardening, and monitoring land in one pass, the same way every time.
3. A handful of one-time steps stay manual by choice — SSH key exchange, a sudoers adjustment, registry login — documented in the project's own docs. Homelab Configs automates what's worth automating; it doesn't chase automating everything just to say it did.
4. Whenever there's a question about whether a machine still matches its definition, run the compliance check for its role. It reports pass or fail against the declared baseline — not "looks fine to me."
5. If something drifted, fix the definition once and re-run the playbook fleet-wide. Every machine of that kind — not just the one you noticed — comes back into line at the same time.

> "I found one Pi had drifted on time sync. I checked the others expecting them to be fine. They weren't — every one had the exact same problem, I just hadn't looked yet. I fixed it everywhere in the time it took to run one Ansible command."
> — Sebastian, on the incident that convinced him this had to be code, not memory

### Getting Started

To bring a new or reinstalled machine into the fleet: run the OS installer, clone the repo, decrypt the vault, and run the playbook for that machine's role. Because every machine of a given role runs from the same definition, the result is disposable and repeatable — rebuild it the same way as many times as you want.

---

## Customer FAQ

### Q: The press release says the only manual step is the OS installer and GNOME tweaks — but there are still manual steps: SSH key exchange, a sudoers tweak, Docker registry login. Isn't that just not true yet? Why publish this vision now instead of after those are closed?

A: Those manual steps are intentionally left manual — they're one-off, post-setup tasks (like enabling dark mode) that take seconds and aren't worth solving. Automating Docker registry login in particular would mean storing credentials somewhere — worst case, in this very repo — which isn't worth the risk for something done once per machine. The one real gap, the sudoers workaround needed on newer Ubuntu versions, is already tracked (GitHub issue #160) and will be closed later. The vision describes the target state on purpose; the honest gap today is small, deliberate, and tracked — not hidden.

### Q: Why does this need Ansible, InSpec, and a whole repo structure for eight machines? Wouldn't a couple of shell scripts do the same job with less to maintain?

A: Anything beyond a throwaway proof of concept lives in a repository here, with version control and CI. Shell scripts alone don't buy that discipline. This project values being able to see history, review changes, and run automated checks — not just get machines configured once.

### Q: What happens when Homelab Configs itself breaks — a role has a bug, an Ansible module's behavior changes, or an upgrade shifts something underneath it?

A: Maintaining the automation is a real, accepted part of the job now — not a side effect that goes away. What keeps that cost bounded: the Ansible roles collection (a separate git submodule) runs its own automated test suite against multiple Ubuntu versions on every push and weekly, so problems can surface in a virtual test environment before they ever touch a real node.

### Q: The compliance checks only validate the OS/security baseline. They wouldn't have caught the NTP incident or the Docker inconsistency that motivated this project. So what does "no drift detected" actually mean — should it be trusted?

A: Compliance checks (InSpec) are one layer, honestly scoped to the OS/security baseline — not a claim of total coverage. The other layer is observability: every node runs a Grafana Alloy agent reporting to Grafana Cloud, and it was in fact a Grafana alert that first caught the clock-sync incident. Between infrastructure tested like software, a compliance baseline, and live monitoring, there's more than one safety net — but no single one of them claims to catch everything.

### Q: What if I want one machine to be different on purpose — say, a test server with one extra tool nobody else needs?

A: Already supported, not a gap. A deliberate exception gets its own Ansible host group or a dedicated playbook for that one machine. "One definition per kind of machine" doesn't mean "one definition for everything."

### Q: If the vault password, SSH keys, or the repo itself get lost, is the fleet locked out?

A: No. SSH keys can be recreated via Ansible, and password-based login to nodes remains available as a fallback. The vault and sudo passwords are the one thing that has to be remembered somewhere — an accepted, bounded risk rather than something needing a formal backup scheme. The repo itself lives on GitHub, so its backup isn't a separate problem to solve. No additional backup system is planned: the machines are disposable by design, so recovery means rebuilding, not restoring from a backup.

### Q: Is this actually faster than manual setup, or does it just feel that way?

A: Never formally measured — manual setup was too long ago to recall precisely. What's true today: reinstalling the main workstation feels fast because the playbook runs unattended; there's no babysitting a manual install. That's a confident belief backed by daily experience, not a measured benchmark.

---

## Internal FAQ

### Q: The Chef InSpec ecosystem is contracting — Chef Infra Server hits EOL in November 2026, InSpec 5.x in April 2026. Is sticking with InSpec still the right long-term bet, or is a migration already looming?

A: For now, yes, by conscious choice — not because the risk isn't real. Those EOL dates create genuine technical debt if left unaddressed indefinitely, but this project explicitly defers dealing with it: a dedicated GitHub issue will track the decision (upgrade InSpec, or move to an alternative) when the deadline actually approaches, rather than solving a problem that isn't urgent yet.

### Q: What's the hardest technical problem in keeping this healthy over time?

A: Ubuntu version bumps breaking role assumptions is the most likely failure mode. The mitigating structure: because everything lives in a git repository, a broken role gets fixed on a branch without ever touching the machines currently running the last-known-good configuration — version control is itself part of the safety net, not just a nice-to-have.

### Q: What's the actual maintenance burden versus the time it saves?

A: Unmeasured, and accepted as such — consistent with the customer-facing answer. There's no plan to start measuring it.

### Q: What do you have to say no to, to keep this sustainable as a solo maintainer?

A: No chasing full automation of one-off manual tasks, and no committing to support or a contribution process for outside users despite the repo being public. One clarification: the README's "Raspberry Pi OS or Ubuntu Server" wording for Pi nodes isn't inaccurate — Raspberry Pi OS is deliberately kept as a valid option for a future Pi node that needs a desktop environment, even though every current Pi runs Ubuntu.

### Q: What actually kills this project?

A: Losing the time or motivation to maintain it, or an upstream dependency (Ansible, InSpec, the community baseline profiles) breaking in a way that's expensive to fix. Not competitive or market forces — those don't apply to a personal system.

### Q: The repo is public on GitHub — what's the actual stance on outside contributions or reuse?

A: A tolerated side effect, not a goal. The real secondary motivation for keeping the repo public is visibility — showing the work, including as a possible talking point down the line (e.g. during a job application). The README's explicit warning against direct reuse stands; this project isn't seeking users or contributors.

### Q: If this succeeds exactly as envisioned, what does Homelab Configs look like in 3 years?

A: Same core shape — workstations, Pi fleet, VMs — with scope deliberately expanded over time and the sudoers/#160 gap closed. One openly acknowledged unknown: new tools or interesting open-source projects encountered along the way may change what specifically gets run, but the commitment to infrastructure-as-code — everything as code — as the operating principle doesn't change.

---

## The Verdict

**Concept strength: solidly forged.** This PRFAQ had an unusual advantage: it isn't pressure-testing a hypothetical, it's ratifying a system that's already had two years of real production use. Almost every hard question resolved into a deliberate, examined decision rather than a hand-wave — that's the mark of a concept that's already been through its gauntlet in practice, not just on paper.

**Forged in steel:**

- The problem is concrete and felt, not abstract: the clock-sync incident (discovered on one Pi, found fleet-wide, fixed fleet-wide in one Ansible run) is a genuinely compelling "before" story that survives repetition.
- The core benefit reframed correctly during coaching — from an invented time-savings number to the real payoff: consistency and disposability. Machines as cattle, not pets.
- Every "isn't this too much machinery for 8 machines?" objection has a real answer grounded in actual practice (2 years of use, CI test matrix on the roles submodule, branch-based fixes that never touch running machines) rather than a defensive one.
- The safety net is honestly scoped and multi-layered: CI testing, an OS/security compliance baseline, and live observability (Grafana Alloy/Cloud) — with a real example of the observability layer catching what the compliance layer wouldn't have.
- Scope boundaries were set deliberately, not left implicit: bare-metal Pi imaging is explicitly out, InSpec's coverage is explicitly limited to the security baseline, and the "public repo but not seeking adoption" stance is stated plainly rather than left ambiguous.

**Needs more heat:**

- The InSpec/Chef ecosystem risk (Chef Infra Server EOL Nov 2026, InSpec 5.x EOL Apr 2026) was deferred, not resolved — "deal with it via a GitHub issue when the time comes" is a plan to make a plan. What it would take to close this properly: open that issue now with the actual EOL dates attached, so "when the time comes" has a trigger instead of relying on memory.
- The maintenance burden is unmeasured, with no plan to measure it, which was accepted honestly — but that also means there's no leading indicator if the automation ever starts costing more than it saves. A lightweight signal (even just a periodic personal gut-check: "am I dreading changes to this repo lately?") would turn an unmeasured risk into a monitored one.

**Cracks in the foundation:** None identified. The concept held under every angle of scrutiny applied — customer skepticism, technical feasibility, sustainability, and the founder's own avoided question all landed on honest, specific, defensible answers rather than exposing a contradiction that undermines the whole premise.

<!-- coaching-notes-stage-3
No launch blockers surfaced. Every question resolved into one of: an accepted trade-off (manual one-off steps stay manual; no credential storage for one-off Docker login; no formal vault/SSH backup scheme), an already-existing capability (per-machine exceptions via dedicated host groups/playbooks — nothing new needed), or a tracked fast-follow (sudoers NOPASSWD workaround, GitHub issue #160).

New facts surfaced that weren't in the Stage 1 artifact scan — carry forward to Architecture/Internal FAQ:
- The Ansible roles collection (git submodule) runs its own CI test matrix against multiple Ubuntu versions, on every push and weekly — a real existing safety net for the "automation itself breaks" risk, not previously documented in the coaching notes.
- Grafana Alloy + Grafana Cloud observability is a second, already-operational safety net alongside InSpec compliance — and it was a Grafana alert, not manual discovery, that first caught the motivating NTP incident. The founding vision's "safety net" is multi-layered (CI testing + compliance baseline + live monitoring), not InSpec alone. This refines the Stage 1 framing where compliance testing was discussed as if it were the sole verification mechanism.
- Node access has a fallback: password-based login to nodes remains available even without SSH keys, and SSH keys themselves are Ansible-recreatable — reduces the "locked out of my own infra" risk to near zero.

Decisions made (not just discussed): explicitly rejected automating Docker registry login (credential storage risk outweighs one-off task cost); explicitly rejected building any backup/recovery tooling beyond what already exists (GitHub for repo, Ansible for key recreation) — disposability of the machines is treated as sufficient recovery strategy; no time-savings metric exists or is planned — qualitative confidence only, not to be dressed up as measured data anywhere downstream.
-->

<!-- coaching-notes-stage-4
Feasibility risks identified, none launch-blocking: (1) Chef InSpec ecosystem contraction (Chef Infra Server EOL Nov 2026, InSpec 5.x EOL Apr 2026) — explicitly deferred, not solved; a dedicated GitHub issue will be opened when the deadline nears. Watch item, not a current-cycle task. (2) Ubuntu version bumps breaking Ansible roles — the most likely ongoing failure mode; mitigated structurally by git branching (fix on a branch, never touch machines running last-known-good config) plus the existing multi-version CI matrix from Stage 3.

Resource/timeline: maintenance burden vs. time saved is unmeasured and will stay unmeasured — a deliberate choice, not an oversight. No timeline pressure exists since this is a personal project with no external deadline.

Correction to a Stage 1 finding: the README's "Raspberry Pi OS or Ubuntu Server" wording for Pi nodes is NOT an inaccuracy needing a fix. It is intentionally broader than current reality — Raspberry Pi OS is deliberately kept available for a future Pi node needing a desktop environment. Retract the earlier "cosmetic inaccuracy, worth fixing" note from Stage 1.

Strategic fit / the avoided question, now said out loud: keeping the repo public is a tolerated side effect, not a goal — outside contribution/reuse is explicitly not sought (README already warns against direct reuse). The real secondary motivation is visibility: showing the work, with a possible payoff as a talking point in future job applications. This is a real but previously-unstated driver worth remembering — it affects how polished/presentable the repo and its docs should be, beyond pure personal utility.

3-year outlook: same core shape (workstations + Pi fleet + VMs), deliberately expanded scope, #160 closed. Explicitly open-ended on *what* gets automated (new tools/projects may be adopted along the way) but not on the *principle* (infrastructure-as-code / everything-as-code stays the operating commitment regardless of which specific tools are used).
-->

<!-- coaching-notes-stage-1
Concept type: internal/personal tool — founding vision document for an existing, already-partially-implemented repo ("configs-homelab"). Not commercial; no unit economics, no customer acquisition — the customer is the single operator (Sebastian) who is also the builder.

Product name: "Homelab Configs" (chosen by user).

Customer: sole homelab operator managing a mixed fleet — 3 Ubuntu workstations/servers (caprica, kobol, picon) + 5 Raspberry Pi nodes (pi4-01/02/03/05, pi5-01, all running Ubuntu despite README wording) + virtual machines.

Problem (concrete anecdotes, user-recalled, NOT documented in-repo — docs/incident-responses/ is empty, confirmed via artifact scan):
- Docker containers meant to run identically across hosts behaved inconsistently.
- NTP/clock sync silently failed on one Pi; user discovered it on a single node, later found the whole fleet was affected, fixed fleet-wide in one Ansible run once caught.
- Periodic repurposing of the Pi fleet historically required manual, per-node reinstall/setup.
Treat these as motivating personal history, not verified/logged incidents — flag as anecdotal if precision is ever needed.

Why this direction over alternatives: user already has ~2 years of Ansible + InSpec + MkDocs investment (24 roles, 4 InSpec profiles, task-based automation). Web research confirmed Ansible+InSpec is a sound, community-validated "GitOps for personal infra" pattern (no dominant turnkey alternative solves mixed physical+VM+Pi fleets end-to-end), so this PRFAQ ratifies an existing sound choice rather than picking between architectures.

Key research findings that shaped scoping decisions (both explicitly resolved via user decision, not left implicit):
1. Bare-metal Pi re-imaging (SD burn / first boot) is explicitly OUT OF SCOPE for Homelab Configs. The vision governs from first boot onward; imaging remains a separate, manual, out-of-scope concern. (Research showed this is a distinct problem space — tools like cloudmesh-pi-burn/MAAS target it — and conflating it with post-boot config would overclaim.)
2. Drift-detection (InSpec) scope is explicitly LIMITED to OS/security baseline compliance (via dev-sec linux-baseline + org's sommerfeld-io/inspec-profiles). It does NOT and will NOT commit to catching the specific incidents that motivated this project (NTP sync, cross-host Docker consistency) — user chose to keep scope narrow rather than expand the vision's promise. These incidents remain valid motivating history for "why config-as-code matters generally" but must not be framed as "and now we test for exactly this."

Gap surfaced but accepted as an honest aspiration, not hidden: the vision's "only manual step is the OS wizard + minor GNOME tweaks" is NOT yet fully true today. Current manual steps beyond that include SSH key exchange, a sudoers NOPASSWD workaround (tracked as open GitHub issue #160), Docker registry login, and GitHub key setup. The press release describes the target end-state (per PRFAQ convention); the Internal FAQ must own this gap honestly rather than imply it's already solved.

Other findings for internal FAQ later: Chef InSpec ecosystem is contracting (Chef Infra Server EOL Nov 2026, InSpec 5.x EOL Apr 2026) though InSpec itself remains maintained — worth a forward-looking risk note, not a blocker. Lightweight alternatives (Goss, Testinfra) exist if InSpec ever needs replacing.

README's OS constraint wording ("Raspberry Pi OS or Ubuntu Server" for Pis) is slightly inaccurate — all current Pi nodes run Ubuntu (Server or Desktop). Cosmetic; worth fixing in README separately, not a PRFAQ blocker.
-->

<!-- coaching-notes-stage-2
Rejected leader-quote drafts: first attempt ("I don't want to remember how I set up a machine. I want to know that if I ask, every machine in this homelab will tell me the truth about itself...") was judged too polished/marketing-voiced by the user — rejected as not sounding like him. Two other alternatives offered ("I don't want to fix machines, I want to rebuild them..." and "If two machines are supposed to be the same, I want to be able to prove it, not just assume it.") were not chosen but are plainer-voice fallbacks worth reusing if the Customer/Internal FAQ needs a similar first-person line later.

Rejected "Getting Started" framing: an initial draft leaned on a fabricated time-savings claim (an invented X-minutes-vs-an-afternoon comparison) with no real data behind it. User corrected this — the real, honest benefit isn't a time number, it's (a) consistency — every machine installs the exact same way — and (b) disposability — environments become cheap to rebuild/discard rather than precious and hand-tuned. This disposability angle became a first-class theme in the solution paragraph and Getting Started section, not just a footnote.

Reframed (not rejected, but tonally corrected): the "manual steps still exist" admission (Stage 1 finding: SSH key exchange, sudoers workaround, registry login) was originally drafted with an apologetic tone ("known, tracked gap between mostly-automated and fully-automated"). User explicitly said these manual steps are okay and the press release can say so plainly. Reframed as a deliberate boundary ("automates what's worth automating, doesn't chase automating everything just to say it did") rather than an unfinished gap to feel bad about. This is a real shift from Stage 1's framing — Internal FAQ should reflect "manual by choice, documented" rather than "gap to close."

Out-of-scope / not used: no dateline convention (city/date header) — user asked to drop it entirely rather than use a placeholder; press release now opens directly with the headline. No competitive positioning language was used in the press release itself (kept for Internal FAQ risk discussion only, per Stage 1 research notes on Ansible/NixOS/InSpec alternatives).
-->
