# Custom GitHub Actions runner image for the trezor-hq-selfhosted ARC scale set.
# Base image ships the runner, Docker CLI and buildx — we only add tooling on top.
# The CI workflow derives image tags from this FROM line; bump it to upgrade the runner.
FROM ghcr.io/actions/actions-runner:2.335.1

USER root

# Base utilities from apt
RUN apt-get update && apt-get install -y --no-install-recommends \
        jq \
        git \
        curl \
        wget \
        unzip \
        zip \
        rsync \
        make \
        ca-certificates \
        gnupg \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# yq (mikefarah Go version, installed as a static binary)
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.53.3
RUN curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
        -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version

# GitHub CLI (official apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && gh --version

# kubectl
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.36.1
RUN curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl version --client

# The runner must start as the unprivileged runner user (uid 1001)
USER runner
