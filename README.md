# gha-runner image

Custom runner image for the ARC scale set
(`gh-arc-runners` namespace). Based on `ghcr.io/actions/actions-runner`
with common tooling preinstalled: jq, yq, gh CLI, kubectl, helm, git,
curl, zip/unzip, rsync, make, python3.

## Upgrading

Renovate maintains everything via `renovate.json` (note: Renovate only
reads config from the repo root, so this works once this directory is
its own repository with Renovate enabled on it):

- GitHub Actions in workflows are pinned to commit SHAs; Renovate bumps
  the digests and version comments.
- The `FROM` runner base image tag (and its digest) in the Dockerfile.
- Tool versions via the `# renovate:` annotations above each
  `ARG *_VERSION` line. Helm is constrained to `<4.0.0` in
  `renovate.json` — drop that rule when you're ready for Helm 4.

Manual fallback: bump the `FROM` tag or `ARG` values directly; image
tags follow the `FROM` line automatically.

Keep `init-dind-externals` on the same image as the `runner` container —
it copies `/home/runner/externals` (container hooks) into the dind
container, and version skew between them can break container jobs.
