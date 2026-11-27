# Custom GitHub Actions runner image for the trezor-hq-selfhosted ARC scale set.
# Base image ships the runner, Docker CLI and buildx — we only add tooling on top.
# The CI workflow derives image tags from this FROM line; bump it to upgrade the runner.
FROM ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300

USER root

# Base utilities from apt.
# libatomic1: official Node.js >= 25 linux-x64 binaries are linked against
# libatomic.so.1; without it a setup-node'd Node 26 dies at exec with an
# "error while loading shared libraries". The upstream base-image fix
# (actions/runner#4640) is not in a released runner yet.
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
        zstd \
        libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# Node on PATH for tooling that runs before actions/setup-node.
# The actions-runner base image ships its own Node runtimes under
# /home/runner/externals/ for JavaScript actions (which it invokes by absolute path),
# and never exports them - so a `run:` step that shells out to `node` (pnpm 12's
# preinstall does `node install.js`, pmg's installer does the same) dies with
# "node: not found" on a bare pod. Symlinking the LTS build matches a GitHub-hosted
# runner; actions/setup-node still prepends its own version later, so the project's
# .node-version keeps winning inside the job. A base-image bump that renames the
# externals directory fails this layer at build time, which is the wanted signal.
RUN ln -sf /home/runner/externals/node24/bin/node /usr/local/bin/node \
 && ln -sf /home/runner/externals/node24/bin/npm  /usr/local/bin/npm \
 && ln -sf /home/runner/externals/node24/bin/npx  /usr/local/bin/npx \
 && node --version && npm --version

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

# docker compose v2 CLI plugin (base image ships docker CLI + buildx, but not compose)
# renovate: datasource=github-releases depName=docker/compose
ARG COMPOSE_VERSION=v5.1.4
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
        "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && docker compose version

# Image variants: GHAC_PATCH=true (default) applies the ghac binary patch and
# CI publishes it as <version>-gha-patched; GHAC_PATCH=false leaves
# Runner.Worker.dll untouched and CI publishes the plain <version> tag.
# The patch layer is last so both variants share every preceding layer.
# NOTE: pools running the patched image MUST set ACTIONS_RESULTS_URL and
# ACTIONS_CACHE_URL (trailing slash!) in the runner pod env — the patch makes
# the runner stop providing them (see patch-results-url.py).
ARG GHAC_PATCH=true
# ghac: keep an operator-set ACTIONS_RESULTS_URL across the runner's step-env
# clobber (see scripts/patch-results-url.py). A base bump that moves the
# literal fails this layer. Based on
# https://gha-cache-server.falcondev.io/getting-started#binary-patch
COPY scripts/patch-results-url.py /tmp/patch-results-url.py
RUN if [ "$GHAC_PATCH" = "true" ]; then \
        python3 /tmp/patch-results-url.py /home/runner/bin/Runner.Worker.dll; \
    fi \
    && rm /tmp/patch-results-url.py

# The runner must start as the unprivileged runner user (uid 1001)
USER runner
