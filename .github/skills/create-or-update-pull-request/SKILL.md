---
name: create-or-update-pull-request
description: 'Automate and standardize the process of creating or updating a pull request from a feature or fix branch (not `main`).'
---


# Create or Update Pull Request


Automate and standardize the process of creating or updating a pull request from a feature or fix branch (not `main`).

**Copilot must actually create the pull request on GitHub using the GitHub CLI (`gh`), not just generate the description.**

## Workflow

1. **Check Branch**: Ensure the current branch is not `main`. If there is already an open pull request for the branch, do not abort—instead, update the existing PR's title and description to reflect the latest commits and repository context. Ignore all closed PRs (merged or unmerged); only open PRs count. If on `main`, exit with an appropriate message.
2. **Generate Description**: Analyze recent commits and repository context to extract relevant changes, features, or fixes. Copilot must generate the entire PR description automatically - no user input required.
3. **Create PR**: Use the GitHub CLI (`gh`) to create a pull request targeting `main` (or the default branch) of the current repository, using the generated description. The PR title must follow [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/#summary) syntax. If authentication is missing, inform the user and prompt them to run `gh auth login` before proceeding.
4. **Completion**: Confirm the PR was created, display the final description for review, and show a link to the PR on GitHub.com.

## Additional Requirements

- The PR title must always follow Conventional Commit syntax.
- The PR body must summarize the changes based on commit messages and repository context, not list the commit messages directly.
- The PR body must be well-formatted Markdown, with real line breaks (not escaped \n), so that GitHub renders it correctly. Do not output the PR body as a single quoted string with embedded \n; output as valid Markdown with actual newlines and spacing for readability.
- Use `###` headings for captions/sections in the PR body.
- Do not link issues in the PR body.
- The PR body must start with a summary paragraph, but do not add a headline to the summary (the PR title is the main headline).

## Decision Points

- PR title must always follow Conventional Commit syntax.
- PR description is always generated automatically from commit history and repository context. User input is not required or accepted.
- The PR body must summarize the changes based on commit messages and repository context, not list the commit messages directly.
- The PR body must be well-formatted Markdown, with appropriate newlines and spacing for readability (not a single block of text).
- Use `###` headings for captions/sections in the PR body.
- Do not link issues in the PR body.
- The PR body must start with a summary paragraph, but do not add a headline to the summary (the PR title is the main headline).

## Quality Criteria

- If not on `main`, always ensure there is an up-to-date open PR for the branch: if no open PR exists, create one; if an open PR exists, update its title and description to reflect the latest commits and repository context. Ignore all closed PRs (merged or unmerged); only open PRs count.
- PR title always follows Conventional Commit syntax.
- PR body is clear, structured, and summarizes changes using commit history and repository context only (no user input).
- PR body is well-formatted Markdown, with appropriate newlines and spacing for readability.
- PR body uses `###` headings for captions/sections.
- PR body does not list commit messages or link issues.
- PR body starts with a summary paragraph (no headline).
- No duplicate or empty PRs are created.

## Example Prompts

- "Open a pull request for this branch."

## Implementation Notes

- Always prefer interacting with GitHub through the GitHub CLI (`gh`) for creating pull requests.
- If the user is not authenticated with `gh`, display an informative message and ask them to run `gh auth login`.
- When generating the PR body, do not include a headline before the summary; the PR title is the main headline.
- Summarize the changes based on commit messages and repository context, do not list commit messages directly.
- The PR body must be well-formatted Markdown, with appropriate newlines and spacing for readability (not a single block of text).
- Use `###` headings for all captions/sections in the PR body.
- Do not link issues in the PR body.
