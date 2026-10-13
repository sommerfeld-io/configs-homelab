<!-- bmad:context -->
<!-- Verified 2026-10-13 against aeef444. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## Known pitfalls

- Run every command a doc shows once before committing the doc, and quote errors from real output. Agents wrote `doctl --format …Size` (the column is `SizeSlug`), a paraphrased `Instance cannot be destroyed` error (the real text is `Resource instance cannot be destroyed`), and a guessed mount path (`/mnt/prod_fantasy_hockey_data`, not `/mnt/<volume-name>`).
- When a decision changes a planning fact, update every planning doc in the same change: `SPEC.md`, `platform-decisions.md`, `stories.yaml`, the epics files, `epic-N-context.md` and the architecture. Updating only the epics file left three docs naming the wrong token variable, SSH keys and mount path.
- When a story creates a resource, copy every epic-level constraint on that resource into the story spec's boundaries. "Resize CPU/RAM only, never disk" was missing from `spec-2-4`, so the droplet shipped with the provider default `resize_disk = true`.
- When renaming a variable that crosses tools (vault, playbook, `.bashrc`, devcontainer `containerEnv`), grep every consumer and fix them all in one commit. The `DIGITALOCEAN_TOKEN` to `DIGITALOCEAN_ACCESS_TOKEN` rename broke the devcontainer chain until `6f8671f`.

<!-- /bmad:context -->
