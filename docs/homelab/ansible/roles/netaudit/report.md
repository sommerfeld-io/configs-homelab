# Role: Netaudit Report

Shared helper of the netaudit roles: renders their console tables and writes their markdown reports. It has no tasks of its own; the other netaudit roles use its files directly.

## What it provides

- `templates/table.txt.j2`: renders a console table from tab-separated rows and a list of columns (`name`, `width`). Each cell is padded to its width and the cells are joined by one space, like `printf "%-<width>s"`. Lines without a tab are printed as notes after the table (e.g. warnings).
- `templates/report.md.j2`: renders a markdown report with a heading, a description, metadata (netaudit role, status, target host, scope, date) and the findings as a padded markdown table. Pipes in cells are escaped.
- `tasks/write.yml`: writes one report. The netaudit roles include it with `ansible.builtin.include_tasks: "{{ role_path }}/../report/tasks/write.yml"`.

## Writing a report

`tasks/write.yml` takes these variables:

| Variable                                             | Description                                                                       |
|------------------------------------------------------|-----------------------------------------------------------------------------------|
| `report_dir`                                         | Directory of the report, usually `{{ <role>_report_dir }}`                        |
| `report_role`                                        | Name of the netaudit role, shown in the report                                    |
| `report_file`                                        | File name; characters other than `A-Z a-z 0-9 . _ -` are replaced by `-`          |
| `report_title`, `report_description`, `report_scope` | Heading, intro sentence and what was scanned                                      |
| `report_status`                                      | `completed` (default), `failed: <error>` or `skipped: <reason>`                   |
| `table_columns`                                      | List of columns (`name`, `width`)                                                 |
| `table_lines`                                        | Tab-separated rows; with more than one column, lines without a tab become notes   |

- The report is written on the Ansible controller (`delegate_to: localhost`) without `become`, so reports of managed hosts don't end up on those hosts, and the files belong to the user running the playbook.
- A report with status `completed` and no rows says "No findings". A `failed` or `skipped` report says that the scan did not run to completion and that this is not a clean result.
- The tasks are tagged `always` (included tasks don't inherit the tags of the include, so `--tags` of a scan still writes its report) and `molecule-idempotence-notest` (reports contain the scan date).
- Reports must not contain secrets; the netaudit roles only pass scan results.

## Markdown Reports

The roles write reports when the play sets `netaudit_reports: true`, to `{{ netaudit_reports_dir }}/<role>/<finding>.md`. Without `netaudit_reports_dir`, each role defaults to `target/netaudit/<role>` in the repository root (derived from the role's location on the controller, not from the working directory). The Netaudit playbook sets both variables.

The role has no variables.
