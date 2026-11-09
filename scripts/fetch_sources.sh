#!/usr/bin/env bash
# Recreates work/melonds-ds and work/melonDS from the pinned upstream commits plus our patches,
# each patch as its own commit on a local branch "gamuroid".
#
# Usage: scripts/fetch_sources.sh            (refuses to touch existing work trees)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=pins.env
. "$ROOT/scripts/pins.env"

mkdir -p "$ROOT/work"
for dir in melonds-ds melonDS; do
    if [ -e "$ROOT/work/$dir" ]; then
        echo "error: $ROOT/work/$dir exists; move it away first" >&2
        exit 1
    fi
done

clone_and_patch() { # url, sha, dir, patch dir
    local url="$1" sha="$2" dir="$3" patches="$4"
    git clone --quiet "$url" "$dir"
    git -C "$dir" checkout --quiet -b gamuroid "$sha"
    test "$(git -C "$dir" rev-parse HEAD)" = "$sha"
    if compgen -G "$patches/*.patch" >/dev/null; then
        git -C "$dir" -c user.name=gamuroid -c user.email=gamuroid@localhost am --quiet --committer-date-is-author-date "$patches"/*.patch
    fi
    echo "$dir: $(git -C "$dir" rev-parse HEAD) (upstream $sha)"
}

clone_and_patch "$WRAPPER_URL" "$WRAPPER_SHA" "$ROOT/work/melonds-ds" "$ROOT/patches/wrapper"
clone_and_patch "$ENGINE_URL" "$ENGINE_SHA" "$ROOT/work/melonDS" "$ROOT/patches/engine"
