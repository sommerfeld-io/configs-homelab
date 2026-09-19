FROM sommerfeldio/devcontainer:0.28.1
LABEL maintainer="sebastian@sommerfeld.io"

# A plain uv-managed venv (not `pip install --break-system-packages`, which would pollute
# the system Python) so every ansible-dev-tools console script (ansible-playbook,
# ansible-lint, ansible-navigator, molecule, ...) lands directly on PATH. `uv tool install`
# was not used here because it only exposes the top-level package's own entry point
# (`adt`, just an LSP launcher), not the scripts of the tools it bundles.
# Runs as root: the base image's shared libraries aren't readable by the non-root
# `vscode` user during a plain `docker build` (only at devcontainer runtime), and /opt
# isn't writable by vscode anyway.
ENV ANSIBLE_DEV_TOOLS_VENV=/opt/venvs/ansible-dev-tools
USER root
RUN uv venv "${ANSIBLE_DEV_TOOLS_VENV}" \
    && uv pip install --python "${ANSIBLE_DEV_TOOLS_VENV}/bin/python" --only-binary :all: ansible-dev-tools
USER vscode
ENV PATH="${ANSIBLE_DEV_TOOLS_VENV}/bin:${PATH}"
