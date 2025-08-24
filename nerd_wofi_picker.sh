#!/usr/bin/env bash
set -euo pipefail

# Handle command line arguments
if [[ "${1:-}" == "--update" ]]; then
  echo "Force updating NerdFont data..."
  FORCE_UPDATE=true
  shift
else
  FORCE_UPDATE=false
fi

# CONFIG: Paths and settings
SCRIPT_DIR="${0%/*}"
DATA_DIR="$SCRIPT_DIR/data"
NERD_TXT_FILE="$DATA_DIR/nerdfont.txt"
CACHE_DIR="$HOME/.cache/nerd-wofi"
PROCESSED_CACHE="$CACHE_DIR/nerdfont_processed.txt"
STYLE_FILE="$SCRIPT_DIR/nerd_wofi_picker_style.css"
mkdir -p "$CACHE_DIR"

# Initialize or update submodule if needed
if [ ! -f "$NERD_TXT_FILE" ]; then
  echo "Initializing NerdFont data submodule..."
  (cd "$SCRIPT_DIR" && git submodule update --init --recursive)
fi

# Check if we should update (once every 7 days)
LAST_UPDATE_FILE="$CACHE_DIR/last_update"
SHOULD_UPDATE=false

if [ ! -f "$LAST_UPDATE_FILE" ] || [ $(($(date +%s) - $(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo 0))) -gt $((7 * 24 * 3600)) ]; then
  SHOULD_UPDATE=true
fi

if [ "$SHOULD_UPDATE" = true ] || [ "$FORCE_UPDATE" = true ]; then
  echo "Updating NerdFont data..."
  if (cd "$SCRIPT_DIR" && git submodule update --remote --merge data); then
    date +%s > "$LAST_UPDATE_FILE"
    rm -f "$PROCESSED_CACHE"
  else
    echo "Warning: Failed to update NerdFont data, using existing version" >&2
  fi
fi

# Pre-process data for better performance if not already done
if [ ! -f "$PROCESSED_CACHE" ] || [ "$NERD_TXT_FILE" -nt "$PROCESSED_CACHE" ]; then
  echo "Processing NerdFont data for better performance..."
  awk '{
    glyph = $1
    $1 = ""
    desc = $0
    gsub(/^[ \t]+/, "", desc)
    printf "%s  %s\n", glyph, desc
  }' "$NERD_TXT_FILE" > "$PROCESSED_CACHE"
fi

# Determine optimal lines based on terminal height
LINES=$(($(tput lines 2>/dev/null || echo 40) / 2))
LINES=$((LINES > 15 ? LINES : 15))
LINES=$((LINES < 40 ? LINES : 40))

# Show via wofi with enhanced styling
WOFI_ARGS=(
  --dmenu
  --insensitive
  --lines "$LINES"
  --width 600
  --height 400
  --prompt "NerdFont:"
  --matching fuzzy
  --sort-order alphabetical
  --no-actions
  --allow-markup
  --cache-file /dev/null
)

# Add custom style if available
if [ -f "$STYLE_FILE" ]; then
  WOFI_ARGS+=(--style "$STYLE_FILE")
fi

CHOICE=$(cat "$PROCESSED_CACHE" | wofi "${WOFI_ARGS[@]}") || exit 1

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
