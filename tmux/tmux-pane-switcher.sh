#!/usr/bin/env bash
# tmux-pane-switcher: fuzzy-find windows and preview their last active pane

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# When called without --inner, launch a tmux popup that re-invokes this script.
if [ "$1" != "--inner" ]; then
  tmux display-popup -w 70% -h 80% -E "$SCRIPT_PATH --inner"
  exit
fi

cyan=$(printf '\033[36m')
green=$(printf '\033[32m')
gray=$(printf '\033[90m')
reset=$(printf '\033[0m')

source "$(dirname "$SCRIPT_PATH")/tmux-ai-palette.sh"
ansi_foreground() {
  local hex=${1#\#}
  printf '\033[38;2;%d;%d;%dm' \
    "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}
working_color=$(ansi_foreground "$TMUX_AI_WORKING_FG")
idle_color=$(ansi_foreground "$TMUX_AI_IDLE_FG")

# The status updater maintains @ai_state; opening the picker never scans agents.
window_rows=$(tmux list-windows -a -F "#{session_id}:#{window_id}	#{session_name}:#{window_index}	#{window_name}	#{window_panes}	state=#{@ai_state}	#{pane_current_path}" 2>/dev/null || true)
[ -z "$window_rows" ] && exit 0

branch_none=$'\001'
branch_lookup_mode="list"
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  declare -A path_branch_map
  declare -A repo_branch_map
  branch_lookup_mode="map"
else
  path_branch_keys=()
  path_branch_vals=()
  repo_branch_keys=()
  repo_branch_vals=()
fi

LOOKUP_VALUE=""
path_branch_get() {
  local key=$1
  local i
  if [ "$branch_lookup_mode" = "map" ]; then
    if [ "${path_branch_map[$key]+x}" ]; then
      LOOKUP_VALUE="${path_branch_map[$key]}"
      return 0
    fi
    return 1
  fi

  for ((i = 0; i < ${#path_branch_keys[@]}; i++)); do
    if [ "${path_branch_keys[$i]}" = "$key" ]; then
      LOOKUP_VALUE="${path_branch_vals[$i]}"
      return 0
    fi
  done
  return 1
}

path_branch_set() {
  local key=$1
  local val=$2
  local i
  if [ "$branch_lookup_mode" = "map" ]; then
    path_branch_map["$key"]="$val"
    return
  fi

  for ((i = 0; i < ${#path_branch_keys[@]}; i++)); do
    if [ "${path_branch_keys[$i]}" = "$key" ]; then
      path_branch_vals[$i]="$val"
      return
    fi
  done
  path_branch_keys+=("$key")
  path_branch_vals+=("$val")
}

repo_branch_get() {
  local key=$1
  local i
  if [ "$branch_lookup_mode" = "map" ]; then
    if [ "${repo_branch_map[$key]+x}" ]; then
      LOOKUP_VALUE="${repo_branch_map[$key]}"
      return 0
    fi
    return 1
  fi

  for ((i = 0; i < ${#repo_branch_keys[@]}; i++)); do
    if [ "${repo_branch_keys[$i]}" = "$key" ]; then
      LOOKUP_VALUE="${repo_branch_vals[$i]}"
      return 0
    fi
  done
  return 1
}

repo_branch_set() {
  local key=$1
  local val=$2
  local i
  if [ "$branch_lookup_mode" = "map" ]; then
    repo_branch_map["$key"]="$val"
    return
  fi

  for ((i = 0; i < ${#repo_branch_keys[@]}; i++)); do
    if [ "${repo_branch_keys[$i]}" = "$key" ]; then
      repo_branch_vals[$i]="$val"
      return
    fi
  done
  repo_branch_keys+=("$key")
  repo_branch_vals+=("$val")
}

RESOLVED_ROOT=""
RESOLVED_BRANCH=""
resolve_branch_for_path() {
  local path=$1
  local dir=$path
  local line
  local root=""

  while :; do
    if repo_branch_get "$dir"; then
      RESOLVED_ROOT="$dir"
      RESOLVED_BRANCH="$LOOKUP_VALUE"
      return
    fi

    if [ -d "$dir/.git" ]; then
      root=$dir
      local head_file="$dir/.git/HEAD"
      if [ -r "$head_file" ]; then
        IFS= read -r line < "$head_file" || true
        case "$line" in
          "ref: refs/heads/"*)
            RESOLVED_ROOT="$root"
            RESOLVED_BRANCH="${line#ref: refs/heads/}"
            return
            ;;
        esac
      fi
      RESOLVED_ROOT="$root"
      RESOLVED_BRANCH="$branch_none"
      return
    fi

    if [ -f "$dir/.git" ]; then
      root=$dir
      IFS= read -r line < "$dir/.git" || true
      case "$line" in
        "gitdir: "*)
          local git_dir="${line#gitdir: }"
          case "$git_dir" in
            /*) ;;
            *) git_dir="$dir/$git_dir" ;;
          esac
          local head_file="$git_dir/HEAD"
          if [ -r "$head_file" ]; then
            IFS= read -r line < "$head_file" || true
            case "$line" in
              "ref: refs/heads/"*)
                RESOLVED_ROOT="$root"
                RESOLVED_BRANCH="${line#ref: refs/heads/}"
                return
                ;;
            esac
          fi
          RESOLVED_ROOT="$root"
          RESOLVED_BRANCH="$branch_none"
          return
          ;;
      esac
      RESOLVED_ROOT="$root"
      RESOLVED_BRANCH="$branch_none"
      return
    fi

    [ "$dir" = "/" ] && break
    dir=${dir%/*}
    [ -z "$dir" ] && dir=/
  done

  RESOLVED_ROOT=""
  RESOLVED_BRANCH="$branch_none"
}

BRANCH_VALUE=""
branch_of_cached() {
  local path=$1
  BRANCH_VALUE=""
  if path_branch_get "$path"; then
    [ "$LOOKUP_VALUE" = "$branch_none" ] || BRANCH_VALUE="$LOOKUP_VALUE"
    return
  fi

  resolve_branch_for_path "$path"
  path_branch_set "$path" "$RESOLVED_BRANCH"
  [ -n "$RESOLVED_ROOT" ] && repo_branch_set "$RESOLVED_ROOT" "$RESOLVED_BRANCH"
  [ "$RESOLVED_BRANCH" = "$branch_none" ] || BRANCH_VALUE="$RESOLVED_BRANCH"
}

ai_rows=""
other_rows=""

while IFS=$'\t' read -r window_target window_key win_name pane_count cached_state path; do
  branch_of_cached "$path"
  branch=$BRANCH_VALUE
  state=${cached_state#state=}

  case "$path" in
    "$HOME"*) path="~${path#"$HOME"}" ;;
  esac

  icon=""
  title_color=$cyan
  case "$state" in
    working) icon="${working_color}●${reset} "; title_color=$working_color ;;
    idle) icon="${idle_color}●${reset} "; title_color=$idle_color ;;
  esac
  pane_label="${pane_count} panes"
  [ "$pane_count" = 1 ] && pane_label="1 pane"

  if [ -n "$branch" ]; then
    display=$(printf "%s%s%s%s: %s%s%s %s[%s]%s %s(%s)%s %s%s%s" \
      "$icon" \
      "$gray" "$window_key" "$reset" \
      "$title_color" "$win_name" "$reset" \
      "$gray" "$pane_label" "$reset" \
      "$green" "$branch" "$reset" \
      "$gray" "$path" "$reset")
  else
    display=$(printf "%s%s%s%s: %s%s%s %s[%s]%s %s%s%s" \
      "$icon" \
      "$gray" "$window_key" "$reset" \
      "$title_color" "$win_name" "$reset" \
      "$gray" "$pane_label" "$reset" \
      "$gray" "$path" "$reset")
  fi

  if [ -n "$state" ]; then
    ai_rows="${ai_rows}${window_target}"$'\t'"${display}"$'\n'
  else
    other_rows="${other_rows}${window_target}"$'\t'"${display}"$'\n'
  fi
done <<< "$window_rows"

export TMUX_WINDOW_PREVIEW_SCRIPT="$(dirname "$SCRIPT_PATH")/tmux-window-preview.py"

target=$(
  # Default fzf layout renders the first rows at the bottom, nearest the prompt.
  printf '%s%s' "$ai_rows" "$other_rows" |
  fzf \
    --ansi \
    --layout=default \
    --no-sort \
    --with-nth=2.. \
    --delimiter=$'\t' \
    --prompt='Window> ' \
    --header='Enter: switch window (last active pane) · Esc: cancel' \
    --preview='python3 "$TMUX_WINDOW_PREVIEW_SCRIPT" {1}' \
    --preview-window='right:60%' \
    --bind='enter:accept' |
  cut -f1
)

# A window target retains its active pane; do not select a pane explicitly.
[ -n "$target" ] && tmux switch-client -t "$target"
exit 0
