# gha-runner image

Custom runner image for the ARC scale set
(`gh-arc-runners` namespace). Based on `ghcr.io/actions/actions-runner`
with common tooling preinstalled: jq, yq, gh CLI, kubectl, docker
compose, git, curl, zip/unzip, rsync, make, python3, zstd (fast
`actions/cache` archive compression).

## ghac cache patch

`scripts/patch-results-url.py` renames the `ACTIONS_RESULTS_URL` literal in the
runner binary so the step-env clobber writes a dead variable and an operator-set
`ACTIONS_RESULTS_URL` survives into steps (used to point `actions/cache` at the
in-cluster [ghac](https://gha-cache-server.falcondev.io) instance; set it on the
runner pod env with a trailing slash). The layer fails the build if a base bump
moves the literal — a lost patch would otherwise fail silently at runtime.

## Upgrading

Renovate maintains everything via `renovate.json` (note: Renovate only
reads config from the repo root, so this works once this directory is
its own repository with Renovate enabled on it):

- GitHub Actions in workflows are pinned to commit SHAs; Renovate bumps
  the digests and version comments.
- The `FROM` runner base image tag (and its digest) in the Dockerfile.
- Tool versions via the `# renovate:` annotations above each
  `ARG *_VERSION` line.

Manual fallback: bump the `FROM` tag or `ARG` values directly; image
tags follow the `FROM` line automatically.

Keep `init-dind-externals` on the same image as the `runner` container —
it copies `/home/runner/externals` (container hooks) into the dind
container, and version skew between them can break container jobs.
