---
title: 'One Alloy installer for both environments: config template variable and fleet-extras switch'
type: 'refactor'
created: '2026-10-13'
status: 'done'
baseline_commit: '76e9e6aafeb580d1e56d4707d060fdc681040054'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Provisioning runs the whole fleet `grafana-cloud/alloy` role on the droplet. That leaves fleet-only parts there: the GitHub token, eBPF capabilities, and the fleet config with `remotecfg` running until the `alloy-config` role overwrites it. The unconditional `state: restarted` also makes every run report changes, on the droplet and on the homelab (Epic 3 retro action 1, `epic-3-retro-item-8-…`).

**Approach (decided with the user in party mode, 2026-10-13):**

- There is one Alloy installer for both environments: the apartment (raspi, cparica, kobol, picon, all one config) and the DigitalOcean servers. The install logic is never duplicated.
- `alloy_config_template` selects the config. Its default is the apartment template.
- `alloy_fleet_extras` (default `true`) gates the GitHub token file, the eBPF capabilities and the override's capability lines.
- The cloud sets both in `configs-cloud/digital-ocean/ansible/vars/main.yml`.
- A handler replaces `state: restarted`.
- The `alloy-config` role is deleted. Its template moves with `git mv` to `configs-cloud/digital-ocean/ansible/templates/alloy/`.

## Boundaries & Constraints

**Always:**

- Role defaults reproduce today's apartment behavior exactly.
- With `alloy_fleet_extras: false`, a host already provisioned loses what it got before: the token file is removed and the binary capabilities are removed. Leftovers are not just left behind.
- Both the Debian and the Arch branches get the switch.
- Planning docs change in the same change (AGENTS.md pitfall).
- The four-Alloy-task exception leaves the docs only after a user-run second provision shows `changed=0`.

**Never:**

- No second Alloy install path.
- No per-host config for apartment machines.
- No change to the apartment template's content.
- Do not run `grafana-agents.yml` or `provision.yml` from the agent: both need the vault password and are user-run.

## I/O & Edge-Case Matrix

| Scenario             | Input / State                                          | Expected Output / Behavior                                                                       | Error Handling                  |
|----------------------|--------------------------------------------------------|--------------------------------------------------------------------------------------------------|---------------------------------|
| Apartment node       | defaults                                               | Same files as today, incl. token and capabilities; Alloy restarts only when config or override changed | N/A                        |
| Droplet, first run   | cloud vars, droplet provisioned with the old setup     | Cloud config written once; token file removed; capabilities and override capability lines removed; one restart | N/A                  |
| Droplet, second run  | same                                                   | `changed=0` for the whole play                                                                   | N/A                             |
| Template path wrong  | `alloy_config_template` points at a missing file       | The template task fails with "Could not find or access"                                          | Fails loudly, no restart        |

</frozen-after-approval>

## Code Map

- `configs-homelab/ansible/roles/grafana-cloud/alloy/tasks/main.yml`
    - Lines 40 and 96 hold the capabilities tasks (Debian/Arch), and lines 52 and 108 the override copies (Debian/Arch).
    - Line 144 is the GitHub token file and line 153 `Template config file` (`force: true`, src fixed).
    - Line 192 is `Restart` (`state: restarted`), the one to replace.
    - `Reload systemd daemon` is unconditional.
- `.../alloy/defaults/main.yml` gets the two new variables. `.../alloy/README.md` has the variables table; `docs/ansible/roles/grafana-cloud/alloy.md` is generated from it by `task docs:generate`.
- New: `.../alloy/handlers/main.yml`.
- `configs-cloud/digital-ocean/ansible/vars/main.yml` is loaded by `provision.yml` as `vars_files`, which outranks role defaults.
- `configs-cloud/digital-ocean/ansible/playbooks/provision.yml` drops the `alloy-config` include.
- `configs-cloud/digital-ocean/ansible/roles/alloy-config/`:
    - The template uses `alloy_environment` and `alloy_stage` only.
    - `tasks/` and `handlers/` are deleted.
- `docker-compose.yml:88` holds the `lint-alloy-config` path list. `.folderslintrc` has the `configs-cloud/*/ansible/...` rules.
- Docs:
    - `docs/cloud/digital-ocean/provisioning.md`: the role list, the "Alloy and Labels" section, and the second-run sentence.
    - `tasks-and-linters.md`: the folderslint row.
- Planning:
    - The epics file: the Story 3.5 `alloy-config` criterion and the Story 3.1 exception.
    - `stories.yaml` `8b`.
    - `epic-3-context.md`: the exception line, plus the 3.5 dependency line naming `alloy-config`.
    - `SPEC.md` CAP-2 and `ARCHITECTURE-SPINE.md` AD-10.

## Tasks & Acceptance

**Execution:**

- [x] Fleet role:
    - Defaults `alloy_config_template: config.alloy.j2` and `alloy_fleet_extras: true`.
    - Template task `src: "{{ alloy_config_template }}"`, notifying `Restart Alloy`.
    - The token task becomes `present` or `absent` by the switch; on `absent` it removes the file.
    - The capabilities tasks become `state: "{{ 'present' if alloy_fleet_extras else 'absent' }}"`.
    - In both override copies, the capability lines are rendered only when the switch is on, and the copies notify the handler.
    - `Restart` is replaced by a `daemon_reload: true` + `state: restarted` handler. The unconditional `Reload systemd daemon` task folds into it.
    - The README variables table gets both variables.
- [x] Cloud:
    - `git mv` the template to `configs-cloud/digital-ocean/ansible/templates/alloy/config.alloy.j2`.
    - Set `alloy_config_template: "{{ playbook_dir }}/../templates/alloy/config.alloy.j2"` and `alloy_fleet_extras: false` in `vars/main.yml`.
    - Remove the `alloy-config` include and `git rm` the rest of the role.
- [x] `docker-compose.yml` lint path, plus a `.folderslintrc` rule for `configs-cloud/*/ansible/templates/*`.
- [x] Docs and planning updates per the Code Map:
    - Story 3.5 scenario: the fleet Alloy role with `alloy_fleet_extras: false` and the cloud template, in a systemd container.
    - AD-10: one sentence on the split.
    - The exception removal waits for the user-run evidence.

**Acceptance Criteria:**

- Given the apartment defaults, when `task lint` runs, then it passes, including `lint-alloy-config` on both templates at their new paths.
- Given a droplet provisioned with the old setup, when the user runs `task cloud:digital-ocean:ansible:provision` twice, then the first run removes `/etc/alloy/github.token` and the capabilities, and the second run ends with `changed=0`.
- Given the droplet after the first run, when checked read-only over SSH, then `getcap` on the Alloy binary prints nothing, `/etc/alloy/config.alloy` has no `remotecfg` or `github` block, and `systemctl is-active alloy` prints `active`.
- Given the change, when `grep -rn alloy-config` runs outside `_bmad-output` history files, then only the `lint-alloy-config` linter name remains.

## Verification

**Commands:**

- `task lint`: expected exit 0.
- `ansible-playbook --syntax-check configs-homelab/ansible/playbooks/grafana-agents.yml --ask-vault-pass`: run by the user if wanted.

**Manual checks (if no CLI):**

- The user runs provision twice and pastes the recap.
- The agent checks the droplet read-only over SSH (`getcap $(command -v alloy)`, `grep -c remotecfg /etc/alloy/config.alloy`, `ls /etc/alloy`).
- The user rolls out `grafana-agents.yml` to the apartment when ready. A first run there restarts Alloy once; a second shows no Alloy changes.

## Implementation Notes

- Capabilities removal deviates from the planned `state: absent`: `community.general.capabilities` 13.5.0 cannot drop the last capability (it runs `setcap "" <path>`, and libcap fails with `empty space is an invalid capability, did you mean -r?`, reproduced locally). The `present` task now runs only with `alloy_fleet_extras: true`. With `false`, a `getcap` read (`changed_when: false`, `check_mode: false`) is followed by `setcap -r` when it shows any capability. Verified locally on a scratch binary: add, remove, a second remove with no change, re-add.
- The token switch is two tasks: `copy` when the switch is on, `file: state=absent` when it is off.
- Beyond the config and override, the handler is also notified by the environment file, the token file tasks, the capability tasks and the docker group task, because the running Alloy only picks those up on a restart. A run with nothing changed still restarts nothing.
- The exception text stays in the epics file, `epic-3-context.md`, `SPEC.md` and `provisioning.md`, each with a note that it is dropped once a user-run second provision shows `changed=0`.
- The droplet's old staging file `/etc/alloy/config.cloud.alloy` (from the deleted `alloy-config` role) is not removed. Alloy does not read it.
- Review patches (by the implementation subagent): `meta: flush_handlers` at the end of the Update Config block; `alloy_fleet_extras | bool` in every conditional and both override `{% if %}`; a `provision.yml` task that removes `/etc/alloy/config.cloud.alloy`; README notes on `false` needing a template without the extras, on how `alloy_config_template` resolves, and the vault path fix. `task lint` exit 0.
- Evidence (user-run, 2026-10-13): the first provision run ended `ok=58 changed=5 failed=0` (capabilities removed, override rewritten, token file removed, one `Restart Alloy`, staging file removed; `Template config file` was already `ok`). The second ended `ok=56 changed=0 failed=0`. Read-only SSH on the droplet: `getcap` on the Alloy binary prints nothing, `/etc/alloy` holds only `config.alloy` and the package sample `config.yaml` (owned by the `alloy` package), `remotecfg` and `github` count 0 in `config.alloy`, the override has only `EnvironmentFile`, `alloy` is `active`, labels `environment = "digital-ocean"` and `stage = "prod"`. The four-Alloy-task exception was then removed from `epic-3-context.md`, the Story 3.1 criterion, `SPEC.md` CAP-2 and `provisioning.md`.

## Review Triage Log

- Restart lost when a later task fails, no flush (blind, edge-case ×2, verification-gap other): medium, patched. `meta: flush_handlers` at the end of the Update Config block; the deleted cloud role had one.
- Staging file `/etc/alloy/config.cloud.alloy` left on the droplet (blind, edge-case): low, patched. One `file: state=absent` task in `provision.yml`.
- `alloy_fleet_extras` as string "false" from `-e` is truthy in Jinja (edge-case): low, patched. `| bool` everywhere.
- Switch off with the fleet template breaks Alloy (blind, edge-case): low, patched as a README note. An assert would add a guard for a combination no caller sets.
- README typo, wrong vault path, template path resolution undocumented (blind ×2): low, patched.
- No automated test for the `false` path and cloud template (verification-gap, blind): medium, deferred to Story 3.5, whose criteria already name this scenario.
- No automated test for the apartment defaults and the handler (verification-gap): medium, deferred (new `deferred-work.md` entry).
- Fresh host starts Alloy before the override and config apply (verification-gap other, edge-case): low, rejected. Same order as before; the flush now applies them at the end of the role instead of the play.
- Planning docs still name the deleted tasks in the exception (blind): low, rejected. The frozen intent keeps the exception until the user-run second provision; it is rewritten then.
- Capability tasks duplicated across Debian and Arch (blind): low, rejected. The role mirrors every task per OS block; merging is a restructure.
- `getcap` fails in `--check` on a fresh host (blind): low, rejected. `--check` on a fresh droplet already fails (accepted in the Epic 3 retro); `libcap2-bin` ships on the image.
- Sprint status not updated (blind): false. It is set at finalize, after the user-run evidence.
- Retro finding 3 and the duplication map not marked (blind): low, rejected. Recording it would edit this build's spec.
- Spec says `state: absent` for capabilities, code uses `getcap`/`setcap -r` (edge-case): low, rejected. The deviation is forced by `community.general.capabilities` 13.5.0 and recorded in the Implementation Notes.
