#!/usr/bin/env bash
set -euo pipefail

# CONFIG: change if you want a local copy or different font file
NERD_TXT_URL="https://raw.githubusercontent.com/8bitmcu/NerdFont-Cheat-Sheet/main/nerdfont.txt"
CACHE="$HOME/.cache/nerd-wofi/nerdfont.txt"
mkdir -p "$(dirname "$CACHE")"

# download/update once every 7 days
if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -c %Y "$CACHE"))) -gt $((7 * 24 * 3600)) ]; then
  curl -sL "$NERD_TXT_URL" -o "$CACHE"
fi

# Show via wofi dmenu; allows fuzzy search; keep the glyph char (first field)
CHOICE=$(cat "$CACHE" | wofi --dmenu -i --lines 25) || exit 1

# Extract glyph (first token) and description (rest)
GLYPH=$(awk '{print $1; exit}' <<<"$CHOICE")
DESC=$(awk '{$1=""; sub(/^ /,""); print}' <<<"$CHOICE")

# copy to clipboard (Wayland wl-copy; fall back to xclip)
if command -v wl-copy >/dev/null 2>&1; then
  printf "%s" "$GLYPH" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
  printf "%s" "$GLYPH" | xclip -selection clipboard
else
  printf "%s\n" "$GLYPH"
fi

# optional: type the glyph using wtype (Wayland) or xdotool for X
# if command -v wtype >/dev/null 2>&1; then
#   wtype --delay 30 "$GLYPH"
# fi

echo "Copied: $GLYPH — $DESC"
