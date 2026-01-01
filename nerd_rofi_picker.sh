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
get_script_dir() {
  local script_path="${BASH_SOURCE[0]}"
  if command -v readlink >/dev/null 2>&1; then
    if SCRIPT_REALPATH=$(readlink -f "$script_path" 2>/dev/null); then
      script_path="$SCRIPT_REALPATH"
    fi
  fi
  while [ -h "$script_path" ]; do
    local script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    script_path="$(readlink "$script_path")"
    [[ $script_path != /* ]] && script_path="$script_dir/$script_path"
  done
  echo "$(cd -P "$(dirname "$script_path")" && pwd)"
}


# CONFIG: Paths and settings
SCRIPT_DIR=$(get_script_dir)
DATA_DIR="$SCRIPT_DIR/data"
NERD_TXT_FILE="$DATA_DIR/nerdfont.txt"
CACHE_DIR="$HOME/.cache/nerd-rofi"
PROCESSED_CACHE="$CACHE_DIR/nerdfont_processed.txt"
STYLE_FILE="$SCRIPT_DIR/nerd_rofi_picker.rasi"
# STYLE_FILE="$HOME/.config/rofi/config.rasi"
CONFIG_FILE="$SCRIPT_DIR/rofi_config"
mkdir -p "$CACHE_DIR"

# Initialize or update submodule if needed
if [ ! -f "$NERD_TXT_FILE" ]; then
  if ! command -v git >/dev/null 2>&1 || [ ! -f "$SCRIPT_DIR/.gitmodules" ]; then
    echo "Error: NerdFont data is missing. Clone this repository with submodules (git clone --recurse-submodules) or run 'git submodule update --init --recursive' in a git checkout." >&2
    exit 1
  fi
  echo "Initializing NerdFont data submodule..."
  if ! (cd "$SCRIPT_DIR" && git submodule update --init --recursive); then
    echo "Error: Failed to initialize NerdFont data. Clone this repository with submodules (git clone --recurse-submodules) or run 'git submodule update --init --recursive' in a git checkout." >&2
    exit 1
  fi
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
    # Add consistent spacing to handle double-width icons
    printf "%-4s %s\n", glyph, desc
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
  -p "󰣇 "
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
declare -a CLEAN_ENV=()
declare -A CLEAN_ENV_SEEN=()

add_env_var() {
  local name="$1"
  local value="${2-}"
  if [[ -n "${CLEAN_ENV_SEEN[$name]:-}" ]]; then
    return
  fi
  CLEAN_ENV+=("$name=$value")
  CLEAN_ENV_SEEN[$name]=1
}

add_env_var HOME "${HOME-}"
add_env_var PATH "${PATH-}"
add_env_var DISPLAY "${DISPLAY-}"
add_env_var WAYLAND_DISPLAY "${WAYLAND_DISPLAY-}"
add_env_var XDG_RUNTIME_DIR "${XDG_RUNTIME_DIR-}"

add_env_var LANG "${LANG-}"
add_env_var LC_ALL "${LC_ALL-}"
add_env_var LC_CTYPE "${LC_CTYPE-}"

while IFS= read -r env_name; do
  [[ $env_name == LC_* ]] || continue
  add_env_var "$env_name" "${!env_name-}"
done < <(compgen -e)

CHOICE=$(cat "$PROCESSED_CACHE" | env -i "${CLEAN_ENV[@]}" rofi "${ROFI_ARGS[@]}") || exit 1

# Extract glyph (first token) and description (rest)
GLYPH=$(awk '{print $1; exit}' <<<"$CHOICE")
DESC=$(awk '{$1=""; sub(/^ /,""); print}' <<<"$CHOICE")

# Function to copy text to the system clipboard
copy_to_clipboard() {
  local text="$1"
  if command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$text" | wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    printf "%s" "$text" | xclip -selection clipboard
  else
    printf "%s\n" "$text"
  fi
}

# copy to clipboard (Wayland wl-copy; fall back to xclip)
copy_to_clipboard "$GLYPH"

# optional: type the glyph using wtype (Wayland) or xdotool for X
# if command -v wtype >/dev/null 2>&1; then
#   wtype --delay 30 "$GLYPH"
# fi

echo "Copied: $GLYPH — $DESC"
