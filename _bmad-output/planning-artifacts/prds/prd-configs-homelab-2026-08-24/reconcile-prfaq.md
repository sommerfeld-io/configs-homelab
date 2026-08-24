---
title: "Input Reconciliation: PRFAQ vs PRD"
created: "2026-08-24"
stage: "Finalize step 2 — input reconciliation"
---

# Input Reconciliation — prfaq-configs-homelab.md

**Input:** `prfaq-configs-homelab.md` (sole original source; no separate product brief)
**Target:** `prd.md` in this same directory

## Gaps found

Ranked by how much a reader relying on the PRD alone (without the PRFAQ) would miss.

### 1. The leader's own voice is completely absent from the Vision

The PRFAQ's press release carries two first-person quotes that anchor the whole concept in a real person's stated standard, not just abstract capability language:

> "Every machine should look the same after setup, every time. If I have to remember something to make that true, the automation isn't done yet."
> — Sebastian, Creator & Operator

> "I found one Pi had drifted on time sync. I checked the others expecting them to be fine. They weren't — every one had the exact same problem, I just hadn't looked yet. I fixed it everywhere in the time it took to run one Ansible command."
> — Sebastian, on the incident that convinced him this had to be code, not memory

Neither quote (nor any first-person voice) appears anywhere in the PRD. The PRD's §1 Vision restates the same facts in third-person, generic capability prose ("Every workstation... is defined, provisioned, and verified as code, so a machine is either running its declared setup or the automation says so"). The PRFAQ's Verdict explicitly praised this quote-driven framing as one of the concept's strongest elements ("The core benefit reframed correctly during coaching... Machines as cattle, not pets" — a line the PRD *did* keep). But the human-voice anchor that made that reframing land is gone. A reader of the PRD alone gets the conclusion ("cattle, not pets") without ever hearing why it mattered to the person who lived through it.

### 2. The Docker cross-host inconsistency incident loses its narrative weight, surviving only as a scope-boundary footnote

The PRFAQ opens with two motivating incidents given equal emotional weight: "a container behaving differently on one host than another that was supposed to be its match — or, memorably, a Raspberry Pi silently losing time sync for weeks." Both are presented as the lived "before" story that makes the problem concrete and felt (the Verdict specifically praises "the problem is concrete and felt, not abstract").

The PRD's §1 Vision keeps only the NTP incident as motivating narrative ("the alternative already happened once: a Raspberry Pi silently lost NTP sync for weeks..."). The Docker inconsistency incident survives only in §4.2 and §5, phrased as a coverage disclaimer ("it does not and will not attempt to catch... cross-host Docker consistency") — i.e., it has been converted entirely into a scope-limitation statement and stripped of its role as one of the two original motivating incidents. A reader of the PRD alone would not know Docker inconsistency was one of the founding "before" stories at all; it reads only as an explicitly-declined feature.

### 3. The README's "Raspberry Pi OS or Ubuntu Server" wording discrepancy is never mentioned or resolved in the PRD

The PRFAQ's Internal FAQ and coaching notes explicitly address this: the README says Pi nodes can run "Raspberry Pi OS or Ubuntu Server," but every current Pi actually runs Ubuntu. This was investigated across two coaching stages — first flagged (Stage 1) as a possible cosmetic inaccuracy worth fixing, then explicitly corrected (Stage 4): "NOT an inaccuracy needing a fix... Raspberry Pi OS is deliberately kept available for a future Pi node needing a desktop environment... Retract the earlier finding."

The PRD's Glossary (§3) defines the Pi fleet (pi4-01/02/03/05, pi5-01) without any mention of OS, and nowhere states that Raspberry Pi OS remains a deliberately-supported future option despite no current node using it. A reader of the PRD alone, cross-referencing the README, would rediscover the apparent discrepancy with none of the resolution already reached in the PRFAQ — re-opening a question that was deliberately closed.

### 4. The "why Ansible/InSpec/a whole repo instead of shell scripts" rationale isn't stated anywhere

The PRFAQ's first Customer FAQ answer directly addresses a real objection: "Anything beyond a throwaway proof of concept lives in a repository here, with version control and CI. Shell scripts alone don't buy that discipline." This is the stated reason the project favors reviewable, tested, version-controlled infrastructure over ad hoc scripting — a scoping/architecture rationale, not just a feature description.

The PRD's §4.4 (Automation Safety Net) describes *what* the CI/git-branching safety net does, but never states *why* that discipline was chosen over a simpler shell-script approach. A reader evaluating "why does this need to be this heavy for 8 machines?" — a question the PRD's own hobby-calibration framing invites — has no answer available in the PRD itself.

### 5. The vault/sudo-password bounded-risk acknowledgment is dropped from the backup Non-Goal

The PRFAQ is explicit that recovery isn't risk-free: "The vault and sudo passwords are the one thing that has to be remembered somewhere — an accepted, bounded risk rather than something needing a formal backup scheme." This names the one genuine single point of failure left after all other recovery paths (GitHub for repo, Ansible for SSH key recreation, password login fallback) are accounted for.

The PRD's §5 Non-Goals ("Formal backup/recovery tooling...") lists the recovery paths but omits this residual risk entirely — it reads as if disposability plus GitHub plus Ansible closes the loop completely, with no acknowledged remaining single point of failure. Minor compared to items 1–4, but it is the one place the PRFAQ names an *accepted risk* rather than a *solved problem*, and that distinction doesn't survive into the PRD.

## Anything verified as fine

- Rejected Docker registry automation (credential-storage risk) — carried into PRD §4.6 and §5 Non-Goals, with the same rationale.
- Rejected fabricated time-savings metric — carried into PRD §7 Success Metrics, explicitly qualitative-only with the same reasoning.
- Public-repo-for-visibility motivation (portfolio/job-talking-point angle) — carried into PRD §2.2 and §4.5.
- Per-machine deliberate exceptions via host groups — carried into PRD FR-2, matching the PRFAQ answer nearly verbatim.
- Bare-metal Pi provisioning explicitly out of scope — carried into PRD §2.2 and §5 Non-Goals.
- InSpec's deliberately narrow OS/security-baseline scope (not claiming to catch NTP/Docker incidents) — carried into PRD §4.2, FR-3, and §5.
- CI multi-version test matrix + git-branch isolation as the "automation itself breaks" safety net — carried into PRD §4.4, FR-5, FR-6.
- Grafana Alloy/Cloud as the layer that actually caught the NTP incident (not InSpec) — carried into PRD §4.3, FR-4.
- The three deliberately-trimmed items (maintenance-burden signal, Chef/InSpec EOL kept as a declined-for-now Non-Goal rather than an active FR, and the removed Open Question about issue #160) — these are confirmed user decisions per the task brief, not gaps, and the PRD reflects each correctly (§5 Non-Goals for the first two; §8 Open Questions is empty for the third).
