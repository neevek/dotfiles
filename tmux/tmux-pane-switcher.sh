#!/usr/bin/env bash
# tmux-pane-switcher: fuzzy-find tmux panes with live preview in a popup

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# When called without --inner, launch a tmux popup that re-invokes this script
if [ "$1" != "--inner" ]; then
  tmux display-popup -w 70% -h 80% -E "$SCRIPT_PATH --inner"
  exit
fi

# --- Inner: runs inside the popup ---

branch_of() {
  local dir=$1
  while :; do
    if [ -d "$dir/.git" ]; then
      head_file="$dir/.git/HEAD"
    elif [ -f "$dir/.git" ]; then
      IFS= read -r line < "$dir/.git" || return
      case "$line" in
        "gitdir: "*)
          head_file=${line#gitdir: }
          case "$head_file" in
            /*) ;;
            *) head_file="$dir/$head_file" ;;
          esac
          head_file="$head_file/HEAD"
          ;;
        *) return ;;
      esac
    else
      [ "$dir" = "/" ] && return
      dir=${dir%/*}
      [ -z "$dir" ] && dir=/
      continue
    fi

    [ -r "$head_file" ] || return
    IFS= read -r line < "$head_file" || return
    case "$line" in
      "ref: refs/heads/"*) printf "%s" "${line#ref: refs/heads/}" ;;
    esac
    return
  done
}

cyan=$(printf '\033[36m')
green=$(printf '\033[32m')
gray=$(printf '\033[90m')
reset=$(printf '\033[0m')

DETECT_SCRIPT="${TMUX_AI_DETECT_SCRIPT:-$HOME/.config/tmux/tmux-ai-detect.sh}"
pane_states=$("$DETECT_SCRIPT" --mode panes 2>/dev/null || true)

state_of_pane() {
  local pane_id=$1
  printf '%s\n' "$pane_states" | awk -F '\t' -v id="$pane_id" '$1 == id { print $2; exit }'
}

# Build the pane list:
#   hidden_pane_id \t colored_display_line
# Display format: [icon] {window_index}: {window_name} ({branch}) ~/path
target=$(
  tmux list-panes -a -F "#{pane_id}	#{window_index}	#{window_name}	#{pane_current_path}" |
  while IFS=$'\t' read -r pane_id win_idx win_name path; do
    branch=$(branch_of "$path")
    state=$(state_of_pane "$pane_id")

    # shorten home dir to ~
    case "$path" in
      "$HOME"*) path="~${path#"$HOME"}" ;;
    esac

    # AI icon: ✨ if working, ● if idle
    icon=""
    case "$state" in
      working) icon="✨" ;;
      idle) icon="● " ;;
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

    # Sort key: 0 for AI panes, 1 for others
    [ -n "$state" ] && sort_key=0 || sort_key=1

    printf "%s\t%s\t%s\n" "$sort_key" "$pane_id" "$display"
  done |
  sort -t$'\t' -k1,1 |
  cut -f2- |
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
