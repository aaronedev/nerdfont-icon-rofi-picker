#!/usr/bin/env bash
#
# Nerd Font Rofi Picker

set -euo pipefail

declare -a TMP_FILES_TO_CLEAN=()

cleanup() {
  local tmp_file
  for tmp_file in "${TMP_FILES_TO_CLEAN[@]:-}"; do
    if [[ -f "$tmp_file" ]]; then
      rm -f "$tmp_file"
    fi
  done
}
trap cleanup EXIT INT TERM

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '${cmd}' not found in PATH." >&2
    exit 1
  fi
}

get_script_dir() {
  local script_path="${BASH_SOURCE[0]}"
  local script_dir
  if command -v readlink >/dev/null 2>&1; then
    local script_realpath
    if script_realpath=$(readlink -f "$script_path" 2>/dev/null); then
      script_path="$script_realpath"
    fi
  fi
  while [[ -L "$script_path" ]]; do
    script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    script_path="$(readlink "$script_path")"
    [[ $script_path != /* ]] && script_path="$script_dir/$script_path"
  done
  echo "$(cd -P "$(dirname "$script_path")" && pwd)"
}

readonly SCRIPT_DIR="$(get_script_dir)"
readonly DATA_DIR="${SCRIPT_DIR}/data"
readonly NERD_TXT_FILE="${DATA_DIR}/nerdfont.txt"
readonly CACHE_DIR="${HOME}/.cache/nerd-rofi"
readonly PROCESSED_CACHE="${CACHE_DIR}/nerdfont_processed.txt"
readonly STYLE_FILE="${SCRIPT_DIR}/nerd_rofi_picker.rasi"
readonly CONFIG_FILE="${SCRIPT_DIR}/rofi_config"
readonly LAST_UPDATE_FILE="${CACHE_DIR}/last_update"
readonly DATA_URL="https://raw.githubusercontent.com/8bitmcu/NerdFont-Cheat-Sheet/master/nerdfont.txt"

download_data() {
  echo "Downloading NerdFont data from upstream..."
  mkdir -p "$DATA_DIR"
  local tmp_download
  tmp_download=$(mktemp)
  TMP_FILES_TO_CLEAN+=("$tmp_download")

  # Limit network exposure by enforcing HTTPS and TLS 1.2+
  if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSfLo "$tmp_download" "$DATA_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget --https-only --secure-protocol=TLSv1_2 -qO "$tmp_download" "$DATA_URL"
  else
    return 1
  fi

  if [[ -s "$tmp_download" ]]; then
    mv "$tmp_download" "$NERD_TXT_FILE"
  else
    echo "Error: Downloaded file is empty." >&2
    exit 1
  fi
}

copy_to_clipboard() {
  local text="$1"
  local desc="$2"
  local fallback=0

  if command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$text" | wl-copy -n
  elif command -v xclip >/dev/null 2>&1; then
    printf "%s" "$text" | xclip -selection clipboard
  else
    echo "Warning: wl-copy and xclip not found; falling back to stdout." >&2
    printf "%s\n" "$text"
    fallback=1
  fi

  if [[ $fallback -eq 1 ]]; then
    echo "Copied (stdout fallback): $desc"
  else
    echo "Copied: $desc"
  fi
}

main() {
  require_cmd rofi
  require_cmd awk
  require_cmd python3

  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Nerd Font Rofi Picker"
    echo "Usage: $(basename "$0") [options]"
    exit 0
  fi

  local force_update=false
  if [[ "${1:-}" == "--update" ]]; then
    echo "Force updating NerdFont data..."
    force_update=true
    shift
  fi

  mkdir -p "$CACHE_DIR"

  if [[ ! -f "$NERD_TXT_FILE" ]]; then
    if [[ -d "${SCRIPT_DIR}/.git" ]] && command -v git >/dev/null 2>&1; then
      echo "Initializing NerdFont data submodule..."
      (cd "$SCRIPT_DIR" && git submodule update --init --recursive) || true
    fi
    if [[ ! -f "$NERD_TXT_FILE" ]]; then
      if ! download_data; then
        echo "Error: NerdFont data missing. Clone recursively or install curl/wget to download." >&2
        exit 1
      fi
    fi
  fi

  local should_update=false
  local current_time
  current_time=$(date +%s)
  local last_update=0

  if [[ -f "$LAST_UPDATE_FILE" ]]; then
    last_update=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo 0)
  fi

  if [[ $((current_time - last_update)) -gt 604800 ]]; then
    should_update=true
  fi

  if [[ "$should_update" == true || "$force_update" == true ]]; then
    echo "Checking for NerdFont data updates..."
    local updated=false

    if [[ -d "${SCRIPT_DIR}/.git" ]] && command -v git >/dev/null 2>&1; then
      if (cd "$SCRIPT_DIR" && git submodule update --remote --merge data 2>/dev/null); then
        updated=true
      fi
    fi

    if [[ "$updated" == false ]]; then
      if download_data; then
        updated=true
      fi
    fi

    if [[ "$updated" == true ]]; then
      date +%s >"$LAST_UPDATE_FILE"
      rm -f "$PROCESSED_CACHE"
    else
      echo "Warning: Failed to update NerdFont data, using existing version" >&2
    fi
  fi

  if [[ ! -f "$NERD_TXT_FILE" ]]; then
    echo "Critical: Nerd Font data missing." >&2
    exit 1
  fi

  if [[ ! -f "$PROCESSED_CACHE" || "$NERD_TXT_FILE" -nt "$PROCESSED_CACHE" ]]; then
    echo "Processing NerdFont data via Python..."
    local tmp_cache
    tmp_cache=$(mktemp)
    TMP_FILES_TO_CLEAN+=("$tmp_cache")

    python3 -c "
import sys
def process_cache(in_path: str, out_path: str) -> None:
    try:
        with open(in_path, 'r', encoding='utf-8') as f_in, \
             open(out_path, 'w', encoding='utf-8') as f_out:
            for line in f_in:
                parts = line.strip().split(maxsplit=1)
                if len(parts) == 2:
                    f_out.write(f'{parts[0]:<4} {parts[1]}\\n')
    except Exception as e:
        sys.stderr.write(f'Cache gen error: {e}\\n')
        sys.exit(1)
if __name__ == '__main__':
    process_cache(sys.argv[1], sys.argv[2])
" "$NERD_TXT_FILE" "$tmp_cache"

    if [[ -s "$tmp_cache" ]]; then
      mv "$tmp_cache" "$PROCESSED_CACHE"
    fi
  fi

  local term_lines
  term_lines=$(($(tput lines 2>/dev/null || echo 40) / 2))
  term_lines=$((term_lines > 15 ? term_lines : 15))
  term_lines=$((term_lines < 40 ? term_lines : 40))

  local rofi_args=(
    -dmenu -i -lines "$term_lines" -p "󰣇 " -matching fuzzy -sort -no-custom
    -format "s" -markup-rows
    -kb-row-left "Left" -kb-row-right "Right"
    -kb-move-char-back "Control+b" -kb-move-char-forward "Control+f"
    -kb-custom-1 "Alt+n" -kb-custom-2 "Alt+h" -kb-custom-3 "Alt+c"
  )

  if [[ -f "$CONFIG_FILE" ]]; then
    rofi_args+=(-config "$CONFIG_FILE")
  fi
  if [[ -f "$STYLE_FILE" ]]; then
    rofi_args+=(-theme "$STYLE_FILE")
  fi

  declare -a clean_env=()
  declare -A clean_env_seen=()

  add_env_var() {
    local name="$1"
    local value="${2-}"
    if [[ -n "${clean_env_seen[$name]:-}" ]]; then
      return
    fi
    clean_env+=("$name=$value")
    clean_env_seen[$name]=1
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

  local choice
  local rofi_status
  set +e
  choice=$(env -i "${clean_env[@]}" rofi "${rofi_args[@]}" <"$PROCESSED_CACHE")
  rofi_status=$?
  set -e

  if [[ $rofi_status -ne 0 && $rofi_status -ne 10 && $rofi_status -ne 11 && $rofi_status -ne 12 ]]; then
    exit 1
  fi
  if [[ -z "$choice" ]]; then
    exit 0
  fi

  local final_text=""
  local desc=""

  case "$rofi_status" in
    0) # Enter -> Glyph
      final_text=$(awk '{printf "%s", $1}' <<<"$choice")
      desc=$(awk '{$1=""; sub(/^ /,""); print}' <<<"$choice" | paste -sd ", " -)
      ;;
    10) # Alt+n -> Name
      final_text=$(awk '{
          s = ""
          for (i=2; i<=NF; i++) s = s (i==2 ? "" : "-") $i
          print s
        }' <<<"$choice" | paste -sd " " -)
      desc="Names: $final_text"
      ;;
    11) # Alt+h -> Hex
      final_text=$(python3 -c "
import sys
def to_hex(data: str) -> str:
    try:
        return ' '.join(f'{ord(g):x}' for g in data.split() if g.strip())
    except Exception as e:
        sys.stderr.write(f'Hex error: {e}\\n')
        sys.exit(1)
if __name__ == '__main__':
    print(to_hex(sys.argv[1]))
" "$(awk '{print $1}' <<<"$choice")")
      desc="Hex: $final_text"
      ;;
    12) # Alt+c -> CSS Class
      final_text=$(awk '{
          s = ""
          for (i=2; i<=NF; i++) s = s (i==2 ? "" : "-") $i
          print "."s
        }' <<<"$choice" | paste -sd " " -)
      desc="CSS: $final_text"
      ;;
  esac

  copy_to_clipboard "$final_text" "$desc"
}

main "$@"
