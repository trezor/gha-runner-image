#!/usr/bin/env python3
"""ghac patch: keep a custom ACTIONS_RESULTS_URL across the runner's step-env clobber.

The stock runner rewrites ACTIONS_RESULTS_URL into every step's environment from the
job message (NodeScriptActionHandler / ContainerActionHandler), which silently pins
actions/cache (service v2 reads this variable and nothing else) to GitHub even when
the operator sets their own URL on the runner.

Fix: rename the UTF-16LE literal `ACTIONS_RESULTS_URL` to an equal-length dummy
`ACTIONS_RESULTS_ORL` in the compiled binary, so the clobber lands on a variable
nobody reads and the operator-provided ACTIONS_RESULTS_URL survives into the step.
Same recipe as https://gha-cache-server.falcondev.io/getting-started#binary-patch,
with build-time assertions added.

The assertions exist because a lost patch fails SILENTLY at runtime (cache quietly
returns to GitHub, no job errors): if a base-image bump moves, splits, or natively
fixes the literal, this script must fail the build loudly instead.
"""
import sys

OLD = "ACTIONS_RESULTS_URL".encode("utf-16-le")
NEW = "ACTIONS_RESULTS_ORL".encode("utf-16-le")
DEFAULT_TARGET = "/home/runner/bin/Runner.Worker.dll"


def patch(path: str) -> int:
    with open(path, "rb") as f:
        data = f.read()

    old_n, new_n = data.count(OLD), data.count(NEW)
    if old_n == 0 and new_n == 1:
        print(f"ghac-patch: {path} is already patched — OK")
        return 0
    if old_n != 1:
        print(
            f"ghac-patch: FATAL — expected the ACTIONS_RESULTS_URL literal exactly "
            f"once in {path}, found old={old_n} new={new_n}.\n"
            "The runner binary changed (literal moved/duplicated, or upstream added a "
            "native override). Do NOT ship this base image: without the patch the "
            "cache silently reverts to GitHub. Investigate before merging the bump.",
            file=sys.stderr,
        )
        return 1

    patched = data.replace(OLD, NEW)
    if patched.count(OLD) != 0 or patched.count(NEW) != 1 or len(patched) != len(data):
        print("ghac-patch: FATAL — post-patch verification failed", file=sys.stderr)
        return 1

    with open(path, "wb") as f:
        f.write(patched)
    print(f"ghac-patch: patched {path} (ACTIONS_RESULTS_URL -> ACTIONS_RESULTS_ORL)")
    return 0


if __name__ == "__main__":
    sys.exit(patch(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_TARGET))
