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
CACHE_DIR="$HOME/.cache/nerd-rofi"
PROCESSED_CACHE="$CACHE_DIR/nerdfont_processed.txt"
# STYLE_FILE="$SCRIPT_DIR/nerd_rofi_picker.rasi"
STYLE_FILE="$HOME/.config/rofi/config.rasi"
CONFIG_FILE="$SCRIPT_DIR/rofi_config"
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
    date +%s >"$LAST_UPDATE_FILE"
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
  }' "$NERD_TXT_FILE" >"$PROCESSED_CACHE"
fi

# Determine optimal lines based on terminal height
LINES=$(($(tput lines 2>/dev/null || echo 40) / 2))
LINES=$((LINES > 15 ? LINES : 15))
LINES=$((LINES < 40 ? LINES : 40))

# Show via rofi with isolated configuration
ROFI_ARGS=(
  -dmenu
  -i
  -lines "$LINES"
  -p "NerdFont:"
  -matching fuzzy
  -sort
  -no-custom
  -format "s"
  -markup-rows
)

# Use isolated config and theme files
if [ -f "$CONFIG_FILE" ]; then
  ROFI_ARGS+=(-config "$CONFIG_FILE")
fi

if [ -f "$STYLE_FILE" ]; then
  ROFI_ARGS+=(-theme "$STYLE_FILE")
fi

# Run rofi with clean environment to avoid config conflicts
CHOICE=$(cat "$PROCESSED_CACHE" | env -i HOME="$HOME" PATH="$PATH" DISPLAY="$DISPLAY" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" rofi "${ROFI_ARGS[@]}") || exit 1

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
