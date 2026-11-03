#!/usr/bin/env bash
# Re-render the skin picker previews (skins/snap/<id>.jpg): starts a throwaway player in
# snapshot mode with a demo playlist, which renders every skin in skinpack.json and quits.
# A window titled "sWamp snapshots" shows up for a few seconds while it works.
set -e
app="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$app/skins/snap"
SWAMP_SNAP="$app/skins/snap" timeout 120 qs -p "$app" 2>&1 | grep --line-buffered "snap:" || true
ls "$app/skins/snap" | wc -l | xargs echo "previews:"
