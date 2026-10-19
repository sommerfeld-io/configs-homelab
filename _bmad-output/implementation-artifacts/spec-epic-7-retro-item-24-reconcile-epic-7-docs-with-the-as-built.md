---
title: 'Epic 7 retro item 24: reconcile the Epic 7 docs and the DNS guard message with the as-built'
type: 'chore'
created: '2026-10-16'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Epic 7 retro (`epic-7-retro-2026-10-15.md`, findings 1-10, action item 1 = sprint action item 24) found that the docs and the DNS guard's failure message no longer match what Story 7.2 built: the guard requires exactly the reserved IP but five places say "among the addresses"; the message recommends `dig`, which the devcontainer lacks; the wildcard is described as an A record to `85.13.131.235` although it is a CNAME to `w00f8074.kasserver.com`; `domain.md` says the reserved IP answers 404 on both schemes; and the new-droplet order, the guard's real reach, the renewal-window caveat of the replacement check, the record TTL, the test droplet's `reserved_ip` need and a future firewall's open ports are missing.

**Approach:** Fix the wording in place, in the files the findings name: role `README.md` (then `task docs:generate` for its copy), `tasks/dns.yml` (fail_msg points at `domain.md` §Check and `getent ahostsv4 <domain>` on the droplet), `deployment.md`, `domain.md`, `replacement.md`, `api-token.md` and `docs/cloud/index.md`. No behavior change: the guard's assertion stays as it is.

</frozen-after-approval>

## Implementation Notes

- Finding 1 ("exactly the reserved IP"): role `README.md` (copy regenerated with `task docs:generate`), `deployment.md` step 2 and §DNS Check, `domain.md` §Check. The `dns.yml` assertion is unchanged.
- Finding 2: the `dns.yml` fail_msg now points at `domain.md` §Check and `getent ahostsv4 <domain>` on the droplet, and names the 2 h cache. The Molecule assertions on the message (`resolves to`, `not to the reserved IP`, `docs/cloud/digital-ocean/domain.md`) still match.
- Finding 3: `domain.md` describes the wildcard as a CNAME to `w00f8074.kasserver.com`; `85.13.131.235` stays only as a dated example that all-inkl can change. The `deployment.md` example message uses `<web-host-ip>`.
- Finding 4: `domain.md` intro and the role README separate `http://` (404) from `https://` (TLS handshake fails) on the reserved IP.
- Finding 5: the new-droplet order (apply, record, wait, deploy) is a numbered list in `domain.md` §Check and a paragraph plus a guard branch in the `docs/cloud/index.md` diagram, whose end node now says the app is reachable at its domain over HTTPS.
- Finding 6: `domain.md` §Record says a test droplet needs `reserved_ip = true`.
- Finding 7: `domain.md` and `deployment.md` state the guard's reach (deploy time, droplet resolver; not renewals, CAA or reachability).
- Finding 8: `replacement.md` gives the renewal-window exception. Decision: it checks the expiry date before the replacement and the ACME account folder in `caddy/data/caddy/acme` instead of naming Caddy log lines that were never observed on the droplet (Epic 7 lesson: no expected output without a live probe).
- Finding 9: `deployment.md` §Certificates and `api-token.md` say a later firewall must allow 80/tcp, 443/tcp and 443/udp.
- Finding 10: the KAS steps in `domain.md` set TTL `7200` and explain how long an old answer lives after a change.

## Review Triage Log

Blind Hunter, one pass (floor N = 6, 10 findings).

| #  | Finding                                                                                           | Verdict     | Route  | Evidence                                                                                                                                                                                         |
|----|---------------------------------------------------------------------------------------------------|-------------|--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1  | No Molecule case for a second address; the new fail_msg text is not asserted                      | medium      | defer  | `verify.yml` tests one wrong address only. The equality check came from Story 7.2, not this change (deferred-work.md). The new message text is only wording, so asserting it was rejected as low |
| 2  | AAAA records are not covered, and the docs do not say so                                          | medium      | patch  | `getent ahostsv4` sees IPv4 only. Both "does not cover" lists now name AAAA, and the domain.md Check says to query `type=AAAA`                                                                   |
| 3  | The firewall note omits SSH                                                                       | low         | patch  | Ansible needs 22/tcp. The api-token.md and deployment.md sentences now name it                                                                                                                   |
| 4  | The new-droplet order waits on public resolvers only, but the deploy reads the droplet's resolver | medium      | patch  | Step 3 in domain.md and the index.md paragraph now include the `getent` check on the droplet                                                                                                     |
| 5  | index.md overstates the claim ("a new droplet") and leaves out the apply task                     | low         | patch  | Now scoped to droplets that run an app; says steps 1 and 2 succeed and names the task                                                                                                            |
| 6  | The diagram leaves out the volume and reserved-IP guards                                          | low         | reject | The diagram never listed step-3 guards. The DNS branch was added because it is the stop a new droplet hits. Adding the other two would be more than a simple fix, and operators rarely hit them  |
| 7  | The test-droplet note sits in domain.md, not in droplet.md                                        | low         | patch  | droplet.md's `example-scratch` is a throwaway template and correctly has `false`. domain.md now names it and links to `droplet.md#reserved_ip` instead of calling it "the test template"         |
| 8  | The replacement exception cannot be verified, and the bullet is a run-on                          | medium      | patch  | Split into its own bullet. It compares `ls -l --time-style=full-iso` of the ACME `users` folder before and after the replacement                                                                 |
| 8b | `grep -c "obtaining certificate"` also fails during a renewal                                     | maybe-false | reject | Would settle with the Caddy log of a renewal on the droplet. The patched check no longer depends on it, and the impact would be low                                                              |
| 9  | The CNAME target `w00f8074.kasserver.com` is hard-coded and undated                               | low         | patch  | The Check now matches "a CNAME to a `*.kasserver.com` host". The wildcard description keeps the current name as a fact                                                                           |
| 10 | fail_msg and the docs disagree on what the check prevents                                         | false       | reject | "Let's Encrypt cannot validate" (wrong address) and "does not start with a name that points elsewhere" describe the same stop. The "does not cover" lists add limits and contradict nothing      |
