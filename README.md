# gha-runner image

Custom runner image for the ARC scale set
(`gh-arc-runners` namespace). Based on `ghcr.io/actions/actions-runner`
with common tooling preinstalled: jq, yq, gh CLI, kubectl, docker
compose, git, curl, zip/unzip, rsync, make, python3, zstd (fast
`actions/cache` archive compression).

## ghac cache

`scripts/patch-results-url.py` renames the `ACTIONS_RESULTS_URL` and `ACTIONS_CACHE_URL`
literals in the runner binary, so the runner cannot overwrite the URLs set on the pod.
Point `ACTIONS_CACHE_URL` and `ACTIONS_RESULTS_URL` at the in-cluster
[ghac](https://gha-cache-server.falcondev.io) instance, with a trailing slash. The build
fails if a base bump moves a literal, since a lost patch is otherwise silent.

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
