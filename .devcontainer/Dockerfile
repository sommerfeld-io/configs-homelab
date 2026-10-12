FROM sommerfeldio/devcontainer:0.29.0-ansible
LABEL maintainer="sebastian@sommerfeld.io"

ARG TARGETARCH
ARG TOFU_VERSION=1.12.7
ARG DOCTL_VERSION=1.183.0

USER root

# OpenTofu (pinned, checksum verified)
RUN set -eux; \
    cd "$(mktemp -d)"; \
    base="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}"; \
    archive="tofu_${TOFU_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    curl -fsSLO "${base}/${archive}"; \
    curl -fsSLO "${base}/tofu_${TOFU_VERSION}_SHA256SUMS"; \
    grep " ${archive}\$" "tofu_${TOFU_VERSION}_SHA256SUMS" | sha256sum -c -; \
    tar -xzf "${archive}" tofu; \
    install -m 0755 tofu /usr/local/bin/tofu

# doctl (pinned, checksum verified)
RUN set -eux; \
    cd "$(mktemp -d)"; \
    base="https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}"; \
    archive="doctl-${DOCTL_VERSION}-linux-${TARGETARCH}.tar.gz"; \
    curl -fsSLO "${base}/${archive}"; \
    curl -fsSLO "${base}/doctl-${DOCTL_VERSION}-checksums.sha256"; \
    grep " ${archive}\$" "doctl-${DOCTL_VERSION}-checksums.sha256" | sha256sum -c -; \
    tar -xzf "${archive}" doctl; \
    install -m 0755 doctl /usr/local/bin/doctl

USER vscode
