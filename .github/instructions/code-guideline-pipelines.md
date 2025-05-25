# Code Guidelines: Pipelines

This guide defines conventions and best practices for writing GitHub Actions workflows to ensure clarity, maintainability, and consistency across repositories.

## File Structure and Naming

* Workflows must reside in `.github/workflows/`.
* File names should describe the pipeline purpose, e.g.:

## Workflow Readability and Modularity

* Minimize logic in YAML: Avoid inline Bash scripts inside the `.yml` file.
* Prefer calling logic from:
    * `Taskfile.yml` (using [go-task](https://taskfile.dev))
    * `docker-compose.yml` services

This approach keeps workflows clean, enables the reuse and local execution of tasks, and makes it easier to test logic outside the CI/CD environment.

## Secrets Management

* Never hard-code credentials, tokens, or sensitive values.
* All usernames, passwords, tokens, API keys, etc., must be stored in GitHub Secrets and referenced as environment variables.

## DockerHub Usage

* Always authenticate when pulling from Docker Hub to avoid rate limits and to support private images.

```yaml
- name: Login to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ secrets.DOCKERHUB_USER }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```
