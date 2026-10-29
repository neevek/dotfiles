#!/usr/bin/env bash
# tmux-ai-status: set per-window @ai_state for status bar AI indicator
# Run at most once every five seconds, independently of animation redraws.
# Sets @ai_state on each window: "working", "idle", or removes it.
# @ai_finished marks unseen working -> idle transitions until the window is visited.
DETECT_SCRIPT="${TMUX_AI_DETECT_SCRIPT:-$HOME/.config/tmux/tmux-ai-detect.sh}"

now=$(date +%s)
last_poll=$(tmux show-option -gqv @ai_status_last_poll)
if [ -n "$last_poll" ] && [ "$((now - last_poll))" -lt 5 ]; then
  exit 0
fi
tmux set-option -g @ai_status_last_poll "$now"

# A failed scan must not clear states or manufacture completion notifications.
window_wants=$("$DETECT_SCRIPT" --mode windows 2>/dev/null) || exit 0
window_current=$(tmux list-windows -a -F "#{session_name}:#{window_index}	#{window_id}	state=#{@ai_state}	#{?@ai_finished,1,0}	#{window_active_clients}")

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

tmux_cmd=(tmux)
tmux_cmd_count=0
append_tmux_cmd() {
  if [ "$tmux_cmd_count" -gt 0 ]; then
    tmux_cmd+=(';')
  fi
  tmux_cmd+=("$@")
  tmux_cmd_count=$((tmux_cmd_count + 1))
}

while IFS=$'\t' read -r win target cur finished viewers; do
  [ -z "$win" ] && continue
  cur=${cur#state=}

  lookup_want_state "$win"
  want=$WANT_STATE

  want_finished=0
  if [ "$want" = idle ] && [ "$viewers" = 0 ]; then
    if [ "$cur" = working ] || [ "$finished" = 1 ]; then
      want_finished=1
    fi
  fi
  if [ "$finished" != "$want_finished" ]; then
    if [ "$want_finished" = 1 ]; then
      append_tmux_cmd set-option -w -t "$target" @ai_finished 1
    else
      append_tmux_cmd set-option -wu -t "$target" @ai_finished
    fi
  fi

  if [ -n "$want" ]; then
    if [ "$cur" != "$want" ]; then
      append_tmux_cmd set-option -w -t "$target" @ai_state "$want"
    fi
  else
    if [ -n "$cur" ]; then
      append_tmux_cmd set-option -wu -t "$target" @ai_state
    fi
  fi
done <<< "$window_current"

if [ "$tmux_cmd_count" -gt 0 ]; then
  "${tmux_cmd[@]}" 2>/dev/null || true
fi

exit 0
