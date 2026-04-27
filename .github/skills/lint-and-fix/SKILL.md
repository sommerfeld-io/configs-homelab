---
name: lint-and-fix
description: 'Run all project linters and fix any errors found. Use when linting fails, before opening a PR, after renaming files or editing YAML/Markdown/workflows, or to validate the repo is clean. Runs task lint (yaml, workflows, filenames, folders, markdown-links) via Docker Compose and surfaces failures for targeted fixes.'
argument-hint: 'Optional: name of a specific linter to run (yaml | workflows | filenames | folders | markdown-links)'
---

# Lint and Fix

Run all (or one specific) project linter and resolve every reported error.

## When to Use

- Before opening a pull request
- After editing `.yml`/`.yaml` files, Markdown files, or GitHub Actions workflows
- After adding, renaming, or moving files or directories
- When CI reports a linting failure and you want a local reproduction

## Procedure

### 1. Run the linters

If an argument was provided, run only that linter:

```bash
docker compose up lint-<argument> --exit-code-from lint-<argument>
```

Otherwise run all linters in order:

```bash
task lint
```

Capture the full terminal output — each Docker Compose service prints its own errors.

### 2. Parse failures

For each service that exits non-zero, extract:
- **Which linter** failed (service name)
- **Which files / lines** are flagged
- **What the rule violation is**

Linter-specific hints:

| Service | What to look for |
|---|---|
| `lint-yaml` | File path + line number + yamllint rule (e.g. `wrong indentation`, `too many spaces`). For GitHub Actions workflow files, do **not** change top-level `on:` to `'on':` or `"on":`. |
| `lint-workflows` | File path + line + actionlint message (e.g. unknown action, invalid expression) |
| `lint-filenames` | Path that violates the naming rule from `.ls-lint.yml` (kebab-case / PascalCase etc.) |
| `lint-folders` | Directory path that is not listed in `.folderslintrc` |
| `lint-markdown-links` | URL or relative path that is broken / unreachable (lychee output) |

### 3. Fix each violation

Apply the minimal change that satisfies the rule:

- **yaml / workflows**: Correct indentation, quoting, or expression syntax in the flagged file.
  - For GitHub Actions workflows, `on:` is required workflow syntax. Never change it to `'on':` or `"on":` just to satisfy yamllint `truthy` warnings.
  - If the only remaining issue is yamllint `truthy` on the top-level workflow `on:` key, leave it unchanged and treat it as an accepted warning.
- **filenames**: Rename the file to match the required convention (see `.ls-lint.yml`). Use `git mv` to keep history.
- **folders**: Either rename the directory to match an allowed pattern or add the new path to `.folderslintrc` if it is intentional.
- **markdown-links**: Update or remove the broken link. For external URLs that are temporarily unreachable, add an exclusion to `.lychee.toml` only if confirmed intentional.

### 4. Re-run to confirm

After all fixes, re-run the same linter(s) from step 1. Repeat until exit code is 0.

### 5. Done

All linters pass. The repo is clean and ready for a pull request.
