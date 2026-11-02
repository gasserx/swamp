#!/bin/bash
# Removes what install.sh added. The plugin itself is removed with:
#   omarchy plugin remove gasserx.swamp
set -uo pipefail
BIN="$HOME/.local/bin/swamp"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
HYPR="$HOME/.config/hypr/hyprland.lua"

DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
"$DIR/bin/swamp" ipc quit >/dev/null 2>&1 || true

[[ -L $BIN ]] && rm -f "$BIN" && echo "✓ removed $BIN"
[[ -f $APPS/swamp.desktop ]] && rm -f "$APPS/swamp.desktop" && echo "✓ removed launcher entry"
update-desktop-database "$APPS" >/dev/null 2>&1 || true
if [[ -f $HYPR ]] && grep -q 'added by sWamp install.sh' "$HYPR"; then
  cp "$HYPR" "$HYPR.bak.swamp-uninstall.$(date +%s)"
  python3 - "$HYPR" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'\n?-- sWamp music player \(added by sWamp install.sh\)\n[^\n]*sWamp[^\n]*\n?', '\n', s)
open(p, 'w').write(s)
PY
  hyprctl reload >/dev/null 2>&1 || true
  echo "✓ removed Hyprland window rule"
fi
echo "Your playlist/settings stay in ~/.local/state/swamp.json (delete it to reset)."
