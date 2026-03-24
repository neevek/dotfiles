#!/usr/bin/env bash
# tmux-pane-switcher: fuzzy-find tmux panes with live preview in a popup

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

DETECT_SCRIPT="${TMUX_AI_DETECT_SCRIPT:-$HOME/.config/tmux/tmux-ai-detect.sh}"
pane_rows=$(tmux list-panes -a -F "#{pane_id}	#{window_index}	#{window_name}	#{pane_current_path}" 2>/dev/null || true)
[ -z "$pane_rows" ] && exit 0

pane_states_tmp=""
detect_pid=""
cleanup_tmp() {
  [ -n "$pane_states_tmp" ] && [ -f "$pane_states_tmp" ] && rm -f "$pane_states_tmp"
}
trap cleanup_tmp EXIT

if [ -x "$DETECT_SCRIPT" ] || [ -f "$DETECT_SCRIPT" ]; then
  pane_states_tmp=$(mktemp "${TMPDIR:-/tmp}/tmux-pane-switcher-states.XXXXXX" 2>/dev/null || true)
  if [ -n "$pane_states_tmp" ]; then
    (
      "$DETECT_SCRIPT" --mode panes >"$pane_states_tmp" 2>/dev/null || true
    ) &
    detect_pid=$!
  fi
fi

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

# Resolve git branches while AI state detection runs in parallel.
while IFS=$'\t' read -r _ _ _ path; do
  [ -z "$path" ] && continue
  branch_of_cached "$path"
done <<< "$pane_rows"

if [ -n "$detect_pid" ]; then
  wait "$detect_pid" 2>/dev/null || true
fi

pane_states=""
if [ -n "$pane_states_tmp" ] && [ -f "$pane_states_tmp" ]; then
  pane_states=$(cat "$pane_states_tmp" 2>/dev/null || true)
elif [ -x "$DETECT_SCRIPT" ] || [ -f "$DETECT_SCRIPT" ]; then
  pane_states=$("$DETECT_SCRIPT" --mode panes 2>/dev/null || true)
fi

state_lookup_mode="list"
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  declare -A pane_state_map
  while IFS=$'\t' read -r pane_id pane_state; do
    [ -z "$pane_id" ] && continue
    pane_state_map["$pane_id"]="$pane_state"
  done <<< "$pane_states"
  state_lookup_mode="map"
else
  pane_state_ids=()
  pane_state_values=()
  while IFS=$'\t' read -r pane_id pane_state; do
    [ -z "$pane_id" ] && continue
    pane_state_ids+=("$pane_id")
    pane_state_values+=("$pane_state")
  done <<< "$pane_states"
fi

STATE_VALUE=""
state_of_pane() {
  local pane_id=$1
  local i
  STATE_VALUE=""
  if [ "$state_lookup_mode" = "map" ]; then
    STATE_VALUE="${pane_state_map[$pane_id]-}"
  else
    for ((i = 0; i < ${#pane_state_ids[@]}; i++)); do
      if [ "${pane_state_ids[$i]}" = "$pane_id" ]; then
        STATE_VALUE="${pane_state_values[$i]}"
        return
      fi
    done
  fi
}

ai_rows=""
other_rows=""

while IFS=$'\t' read -r pane_id win_idx win_name path; do
  branch_of_cached "$path"
  branch=$BRANCH_VALUE
  state_of_pane "$pane_id"
  state=$STATE_VALUE

  case "$path" in
    "$HOME"*) path="~${path#"$HOME"}" ;;
  esac

  icon=""
  case "$state" in
    working) icon="${green}●${reset} " ;;
    idle) icon="${gray}●${reset} " ;;
  esac

  if [ -n "$branch" ]; then
    display=$(printf "%s%s%s%s: %s%s%s %s(%s)%s %s%s%s" \
      "$icon" \
      "$gray" "$win_idx" "$reset" \
      "$cyan" "$win_name" "$reset" \
      "$green" "$branch" "$reset" \
      "$gray" "$path" "$reset")
  else
    display=$(printf "%s%s%s%s: %s%s%s %s%s%s" \
      "$icon" \
      "$gray" "$win_idx" "$reset" \
      "$cyan" "$win_name" "$reset" \
      "$gray" "$path" "$reset")
  fi

  if [ -n "$state" ]; then
    ai_rows="${ai_rows}${pane_id}"$'\t'"${display}"$'\n'
  else
    other_rows="${other_rows}${pane_id}"$'\t'"${display}"$'\n'
  fi
done <<< "$pane_rows"

target=$(
  printf '%s%s' "$ai_rows" "$other_rows" |
  fzf \
    --ansi \
    --with-nth=2.. \
    --delimiter=$'\t' \
    --preview='
      tmux capture-pane -t {1} -p -e | tail -n "$FZF_PREVIEW_LINES"
    ' \
    --preview-window='right:60%' \
    --bind='enter:accept' |
  cut -f1
)

[ -n "$target" ] && tmux switch-client -t "$target"
exit 0
