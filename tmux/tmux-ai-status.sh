#!/usr/bin/env bash
# tmux-ai-status: set per-window @ai_state for status bar AI indicator
# Run periodically via tmux status-interval.
# Sets @ai_state on each window: "working", "idle", or removes it.
# Use in window-status-format:
#   #{?#{==:#{@ai_state},working},✨ ,#{?#{==:#{@ai_state},idle},● ,}}

# Step 1: find AI pane IDs, grouped by window (session:window_index)
ai_info=$(
  {
    tmux list-panes -a -F "PANE #{pane_pid} #{pane_id} #{session_name}:#{window_index}"
    ps -eo pid=,ppid=,command=
  } | awk '
    /^PANE / { pane_pid[$2] = $3; pane_win[$2] = $4; next }
    {
      pid = $1; ppid = $2
      cmd = ""; for (i = 3; i <= NF; i++) cmd = cmd (i>3?" ":"") $i
      parent[pid] = ppid
      cmds[pid] = cmd
    }
    END {
      for (pid in cmds) {
        c = tolower(cmds[pid])
        if (c ~ /claude/ || c ~ /codex/) ai[pid] = 1
      }
      for (pid in ai) {
        p = pid
        for (i = 0; i < 50 && p > 1; i++) {
          if (p in pane_pid) {
            id = pane_pid[p]
            win = pane_win[p]
            # record pane_id per window (may have multiple)
            if (!(win in win_panes))
              win_panes[win] = id
            else
              win_panes[win] = win_panes[win] " " id
            break
          }
          if (!(p in parent)) break
          p = parent[p]
        }
      }
      for (win in win_panes) print win, win_panes[win]
    }'
)

# Collect all windows so we can clear stale @ai_state
all_windows=$(tmux list-windows -a -F "#{session_name}:#{window_index}")

# Build set of windows that have AI panes
declare -A ai_windows

# Step 2: for each AI window, check pane content to determine state
while read -r win pane_ids; do
  [ -z "$win" ] && continue
  state="idle"
  for pane_id in $pane_ids; do
    # Only check the LAST non-empty line — older visible output may contain stale matches
    last_line=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null | awk 'NF{line=$0} END{print line}')
    case "$last_line" in
      *"esc to interrupt"*) state="working"; break ;;
    esac
  done
  ai_windows[$win]=$state
done <<< "$ai_info"

# Step 3: update @ai_state on every window
for win in $all_windows; do
  if [ -n "${ai_windows[$win]+x}" ]; then
    tmux set-option -w -t "$win" @ai_state "${ai_windows[$win]}" 2>/dev/null
  else
    tmux set-option -wu -t "$win" @ai_state 2>/dev/null
  fi
done
