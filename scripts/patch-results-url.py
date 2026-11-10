#!/usr/bin/env python3
"""Rename the runner's URL literals to same-length dummies so its per-step env clobber
misses them and our pod-level URLs reach the steps. The checks are the point: a patch lost
to a base bump fails silently at runtime, so it has to fail the build.
"""
import sys

LITERALS = [
    ("ACTIONS_RESULTS_URL", "ACTIONS_RESULTS_ORL"),
    ("ACTIONS_CACHE_URL", "ACTIONS_CACHE_ORL"),
]
DEFAULT_TARGET = "/home/runner/bin/Runner.Worker.dll"


def fatal(msg: str) -> int:
    print(f"ghac-patch: FATAL — {msg}", file=sys.stderr)
    return 1


def patch(path: str) -> int:
    with open(path, "rb") as f:
        data = f.read()
    original_len = len(data)

    for old, new in LITERALS:
        if len(old) != len(new):
            return fatal(f"replacement {new!r} is not equal length to {old!r}")
        old_b, new_b = old.encode("utf-16-le"), new.encode("utf-16-le")
        old_n, new_n = data.count(old_b), data.count(new_b)

        if old_n == 0 and new_n == 1:
            print(f"ghac-patch: {old} already patched — OK")
            continue
        if old_n != 1:
            return fatal(
                f"expected the {old} literal exactly once in {path}, "
                f"found old={old_n} new={new_n}.\n"
                "The runner binary changed (literal moved/duplicated, or upstream added a "
                "native override). Do NOT ship this base image: without the patch the cache "
                "silently reverts to GitHub. Investigate before merging the bump."
            )

        data = data.replace(old_b, new_b)

    for old, new in LITERALS:
        old_b, new_b = old.encode("utf-16-le"), new.encode("utf-16-le")
        if data.count(old_b) != 0 or data.count(new_b) != 1 or len(data) != original_len:
            return fatal(f"post-patch verification failed for {old} in {path}")

    with open(path, "wb") as f:
        f.write(data)
    names = ", ".join(f"{o} -> {n}" for o, n in LITERALS)
    print(f"ghac-patch: patched {path} ({names})")
    return 0


if __name__ == "__main__":
    sys.exit(patch(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_TARGET))
