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

# Pre-compute set of pane IDs running claude or codex.
# Single ps call: find claude/codex PIDs, walk ppid chain up to a pane PID.
ai_panes=" $(
  {
    tmux list-panes -a -F "PANE #{pane_pid} #{pane_id}"
    ps -eo pid=,ppid=,command=
  } | awk '
    /^PANE / { pane[$2] = $3; next }
    {
      pid = $1; ppid = $2
      cmd = ""; for (i = 3; i <= NF; i++) cmd = cmd (i>3?" ":"") $i
      parent[pid] = ppid
      cmds[pid] = cmd
    }
    END {
      # find all claude/codex PIDs
      for (pid in cmds) {
        c = tolower(cmds[pid])
        if (c ~ /claude/ || c ~ /codex/) ai[pid] = 1
      }
      # walk each AI pid up the ppid chain to find its pane
      for (pid in ai) {
        p = pid
        for (i = 0; i < 50 && p > 1; i++) {
          if (p in pane) { found[pane[p]] = 1; break }
          if (!(p in parent)) break
          p = parent[p]
        }
      }
      for (id in found) printf "%s ", id
    }
  '
) "

# Build the pane list:
#   hidden_pane_id \t colored_display_line
# Display format: [icon] {window_index}: {window_name} ({branch}) ~/path
target=$(
  tmux list-panes -a -F "#{pane_id}	#{window_index}	#{window_name}	#{pane_current_path}" |
  while IFS=$'\t' read -r pane_id win_idx win_name path; do
    branch=$(branch_of "$path")

    # shorten home dir to ~
    case "$path" in
      "$HOME"*) path="~${path#"$HOME"}" ;;
    esac

    # AI icon: ✨ if working, ● if idle
    icon=""
    case "$ai_panes" in
      *" $pane_id "*)
        last_line=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null | awk 'NF{line=$0} END{print line}')
        case "$last_line" in
          *"esc to interrupt"*) icon="✨ " ;;
          *) icon="● " ;;
        esac
        ;;
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
    case "$ai_panes" in
      *" $pane_id "*) sort_key=0 ;;
      *) sort_key=1 ;;
    esac

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
