#!/usr/bin/env bash
# tmux-ai-status: set per-window @ai_state for status bar AI indicator
# Run periodically via tmux status-interval.
# Sets @ai_state on each window: "working", "idle", or removes it.
# Use in window-status-format:
#   #{?#{==:#{@ai_state},working},✨ ,#{?#{==:#{@ai_state},idle},● ,}}
DETECT_SCRIPT="${TMUX_AI_DETECT_SCRIPT:-$HOME/.config/tmux/tmux-ai-detect.sh}"

window_wants=$("$DETECT_SCRIPT" --mode windows 2>/dev/null || true)
window_current=$(tmux list-windows -a -F "#{session_name}:#{window_index}	#{@ai_state}")

lookup_mode="list"
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  declare -A want_map
  while IFS=$'\t' read -r win state; do
    [ -z "$win" ] && continue
    want_map["$win"]="$state"
  done <<< "$window_wants"
  lookup_mode="map"
else
  want_ids=()
  want_states=()
  while IFS=$'\t' read -r win state; do
    [ -z "$win" ] && continue
    want_ids+=("$win")
    want_states+=("$state")
  done <<< "$window_wants"
fi

WANT_STATE=""
lookup_want_state() {
  local win=$1
  local i
  WANT_STATE=""
  if [ "$lookup_mode" = "map" ]; then
    WANT_STATE="${want_map[$win]-}"
    return
  fi

  for ((i = 0; i < ${#want_ids[@]}; i++)); do
    if [ "${want_ids[$i]}" = "$win" ]; then
      WANT_STATE="${want_states[$i]}"
      return
    fi
  done
}

while IFS=$'\t' read -r win cur; do
  [ -z "$win" ] && continue

  lookup_want_state "$win"
  want=$WANT_STATE

  if [ -n "$want" ]; then
    if [ "$cur" != "$want" ]; then
      tmux set-option -w -t "$win" @ai_state "$want" 2>/dev/null
    fi
  else
    if [ -n "$cur" ]; then
      tmux set-option -wu -t "$win" @ai_state 2>/dev/null
    fi
  fi
done <<< "$window_current"

exit 0
