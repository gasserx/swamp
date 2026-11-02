#!/bin/bash
# Optional extras for the sWamp Omarchy plugin:
#   - `swamp` command in ~/.local/bin
#   - app-launcher entry (Super+Space) with the sWamp icon
#   - Hyprland window rule (floating, centered, fully opaque)
#   - with --default-player: open audio files in sWamp by default
# Run again any time; it only adds what is missing. Undo with ./uninstall.sh.
set -euo pipefail

DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
HYPR="$HOME/.config/hypr/hyprland.lua"
MIME="audio/mpeg;audio/mp3;audio/flac;audio/x-flac;audio/ogg;audio/x-vorbis+ogg;audio/opus;audio/mp4;audio/x-m4a;audio/aac;audio/wav;audio/x-wav;audio/x-ms-wma;audio/x-mpegurl;audio/mpegurl;"

default_player=0
for a in "$@"; do
  case $a in
    --default-player) default_player=1 ;;
    -h|--help) sed -n 2,8p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done

# --- dependencies -----------------------------------------------------------
missing=()
for cmd in qs ffprobe pw-record jq python3 hyprctl; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
pacman -Q qt6-multimedia-ffmpeg >/dev/null 2>&1 || missing+=("qt6-multimedia-ffmpeg")
if (( ${#missing[@]} )); then
  echo "Missing: ${missing[*]}"
  echo "Install with: omarchy pkg add ffmpeg pipewire jq python qt6-multimedia-ffmpeg"
  exit 1
fi

# --- launcher ---------------------------------------------------------------
mkdir -p "$BIN"
ln -sfn "$DIR/bin/swamp" "$BIN/swamp"
echo "✓ command: $BIN/swamp"

# --- desktop entry ----------------------------------------------------------
mkdir -p "$APPS"
cat > "$APPS/swamp.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=sWamp
GenericName=Music Player
Comment=Retro MP3 player with a spectrum analyzer and playlist
Exec=$DIR/bin/swamp %U
Icon=$DIR/app/assets/icon.png
Terminal=false
StartupWMClass=swamp
Categories=AudioVideo;Audio;Player;
MimeType=$MIME
Actions=Enqueue;

[Desktop Action Enqueue]
Name=Add to sWamp playlist
Exec=$DIR/bin/swamp --enqueue %U
DESKTOP
update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "✓ app launcher entry: $APPS/swamp.desktop"

# --- Hyprland window rule ---------------------------------------------------
if [[ -f $HYPR ]]; then
  if ! grep -q '"^(sWamp)\$"' "$HYPR"; then
    cp "$HYPR" "$HYPR.bak.swamp.$(date +%s)"
    cat >> "$HYPR" <<'RULE'

-- sWamp music player (added by sWamp install.sh)
o.window({ title = "^(sWamp)$" }, { float = true, center = true, tag = "-default-opacity", opacity = "1 1" })
RULE
    hyprctl reload >/dev/null 2>&1 || true
    echo "✓ Hyprland window rule added to $HYPR"
  else
    echo "✓ Hyprland window rule already present"
  fi
else
  echo "! $HYPR not found; skipped the window rule (sWamp floats itself anyway)"
fi

# --- default player ---------------------------------------------------------
if (( default_player )); then
  IFS=';' read -ra types <<< "$MIME"
  for t in "${types[@]}"; do [[ -n $t ]] && xdg-mime default swamp.desktop "$t"; done
  echo "✓ sWamp is now the default audio player"
fi

echo
echo "Done. Start it with: swamp   (or Super+Space → sWamp, or the bar button)"
