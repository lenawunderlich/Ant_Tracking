#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VIDEOS_DIR="/media/angela/PUMBAAAUPA/Videosout/"
DEFAULT_SETTINGS="/media/angela/PUMBAAAUPA/default.settings"
DEFAULT_DATE="20251125"

DATE="${1:-$DEFAULT_DATE}"
TARGET_HOUR="${2:-}"
VIDEOS_DIR="${3:-$DEFAULT_VIDEOS_DIR}"
SETTINGS="${4:-$DEFAULT_SETTINGS}"

if [[ -n "$TARGET_HOUR" && ! "$TARGET_HOUR" =~ ^([01][0-9]|2[0-3])$ ]]; then
  echo "ERROR: hour must be 00..23, got '$TARGET_HOUR'" >&2
  exit 1
fi

process_date() {
  local current_date="$1"
  local current_dir="$2"
  local current_hour="${3:-}"

  echo "VIDEOS_DIR=$current_dir"
  echo "SETTINGS=$SETTINGS"

  if [[ -n "$current_hour" ]]; then
    echo "Process date=$current_date only hour=$current_hour"
  else
    echo "Process date=$current_date all hours"
  fi

  while IFS= read -r f; do
    base=${f##*/}
    rest=${base#*${current_date}-}
    time_part=${rest%%-*}
    file_hour=${time_part:0:2}
    file_min=${time_part:2:2}

    if [[ -z "$file_hour" || -z "$file_min" ]]; then
      echo "skip unparseable filename: $base"
      continue
    fi

    if [[ -n "$current_hour" && "$file_hour" != "$current_hour" ]]; then
      continue
    fi

    group_dir="${current_dir}/${current_date}-${file_hour}00"
    mkdir -p "$group_dir"
    mv "$f" "$group_dir/"
  done < <(find "$current_dir" -maxdepth 1 -type f -name "VTKA_AuPa_${current_date}-*.mp4" | sort)

  for group_dir in "$current_dir"/${current_date}-*; do
    [ -d "$group_dir" ] || continue

    if [[ -n "$current_hour" ]]; then
      group_name=$(basename "$group_dir")
      if [[ "$group_name" != "${current_date}-${current_hour}00" ]]; then
        continue
      fi
    fi

    clips=()
    while IFS= read -r clip; do
      clips+=("$clip")
    done < <(find "$group_dir" -maxdepth 1 -type f -name "*.mp4" | sort)
    [ ${#clips[@]} -gt 0 ] || { echo "skip empty folder $group_dir"; continue; }

    list="[\"${clips[0]}\""
    for ((i=1; i<${#clips[@]}; i++)); do
      list+=",\"${clips[$i]}\""
    done
    list+="]"

    echo "Running trex for folder $(basename "$group_dir") (${#clips[@]} clips)"
    (
      cd "$group_dir"
      trex -i "$list" -s "$SETTINGS" -task convert -auto_quit
    )
  done
}

if [[ "$DATE" == "all" ]]; then
  shopt -s nullglob
  for d in "$VIDEOS_DIR"/*; do
    [[ -d "$d" ]] || continue
    current_name=$(basename "$d")
    if [[ "$current_name" =~ ^[0-9]{8}$ ]]; then
      process_date "$current_name" "$d" "$TARGET_HOUR"
    fi
  done
  exit 0
fi

process_date "$DATE" "$VIDEOS_DIR" "$TARGET_HOUR"
