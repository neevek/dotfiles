#!/usr/bin/env bash
# tmux-ai-status: set per-window @ai_state for status bar AI indicator
# Run periodically via tmux status-interval.
# Sets @ai_state on each window: "working", "idle", or removes it.
# Use in window-status-format:
#   #{?#{==:#{@ai_state},working},✨ ,#{?#{==:#{@ai_state},idle},● ,}}
DETECT_SCRIPT="${TMUX_AI_DETECT_SCRIPT:-$HOME/.config/tmux/tmux-ai-detect.sh}"

window_wants=$("$DETECT_SCRIPT" --mode windows 2>/dev/null || true)
window_current=$(tmux list-windows -a -F "#{session_name}:#{window_index}	#{@ai_state}")

get_window_state() {
  local source="$1"
  local win="$2"
  printf '%s\n' "$source" | awk -F '\t' -v w="$win" '$1 == w { print $2; exit }'
}

tmux list-windows -a -F "#{session_name}:#{window_index}" | while IFS= read -r win; do
  [ -z "$win" ] && continue

  want=$(get_window_state "$window_wants" "$win")
  cur=$(get_window_state "$window_current" "$win")

  if [ -n "$want" ]; then
    if [ "$cur" != "$want" ]; then
      tmux set-option -w -t "$win" @ai_state "$want" 2>/dev/null
    fi
  else
    if [ -n "$cur" ]; then
      tmux set-option -wu -t "$win" @ai_state 2>/dev/null
    fi
  fi
done

exit 0
