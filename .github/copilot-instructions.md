# GitHub Copilot Instructions

## Code Guideline: Pipelines

This guide defines conventions and best practices for writing GitHub Actions workflows to ensure clarity, maintainability, and consistency across repositories.

### File Structure and Naming

- Workflows must reside in `.github/workflows/`.
- File names should describe the pipeline purpose.

### Workflow Readability and Modularity

- Minimize logic in YAML: Avoid inline Bash scripts inside the `.yml` file.
- Prefer calling logic from:
  - `taskfile.yml` (using a [taskfile](https://taskfile.dev))
  - `docker-compose.yml` services

This approach keeps workflows clean, enables the reuse and local execution of tasks, and makes it easier to test logic outside the CI/CD environment.

### Secrets Management

- Never hard-code credentials, tokens, or sensitive values.
- All usernames, passwords, tokens, API keys, etc., must be stored in GitHub Secrets and referenced as environment variables.
- Define multiple environemnts when helpful and define secrets inside these environemnts.

### DockerHub Usage

- Always authenticate when pulling from Docker Hub to avoid rate limits and to support private images.

```yaml
- name: Login to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ secrets.DOCKERHUB_USER }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

## Guideline: Pull Requests

- Ensure the pull request (PR) has a clear, descriptive title.
- Confirm the PR description explains the purpose and scope of the change.
- Verify that all checks from all relevant Github Actions have passed.
- Ensure code passes all linter checks as configured in the repository.
- Assign at least one reviewer.

### When to create a Pull Request

- Always create a Pull Request (PR) as soon as you begin implementing a change in a branch.
- Provide a PR description that reflects the reason for the change as soon as possible.
- Descriptions of technical changes can be added and updated as the implementation evolves.

### Reviews

- **Always Request:** `sebastian-sommerfeld-io`
- Only mark the PR as ready for review if all checklist items are satisfied.

### Merge Rules

- **No Merge Conflicts**: Merging is prevented if conflicts exist.
- **Title and Commit Pattern**: Both PR titles and all commit messages must follow the pattern `^(fix|feat|build|chore|ci|docs|style|refactor|perf|test)/[a-z0-9._-]+$`.
