#!/usr/bin/env bash
# tmux-ai-detect: infer AI pane/window activity.
# Modes:
#   --mode panes   -> outputs "<pane_id>\t<state>"
#   --mode windows -> outputs "<session:window>\t<state>"
#
# States:
#   working: recent bottom lines contain interrupt hints ("esc to interrupt")
#   idle:    pane is AI-associated but interrupt hint is not visible

mode="windows"
if [ "$1" = "--mode" ] && [ -n "$2" ]; then
  mode="$2"
fi

case "$mode" in
  panes|windows) ;;
  *)
    echo "usage: $0 [--mode panes|windows]" >&2
    exit 1
    ;;
esac

allowlist=$(tmux show-option -gqv @ai_commands 2>/dev/null)
[ -z "$allowlist" ] && allowlist="claude,codex"

pane_has_interrupt_marker() {
  local pane_id="$1"
  tmux capture-pane -t "$pane_id" -p -e -S -120 2>/dev/null | awk -v scan_lines=6 '
    function strip_ansi(s) {
      gsub(/\r/, "", s)
      gsub(/\033\[[0-9;?]*[ -\/]*[@-~]/, "", s)
      gsub(/\033\][^\a]*\a/, "", s)
      gsub(/\033\][^\033]*\033\\/, "", s)
      return s
    }
    {
      line = tolower(strip_ansi($0))
      if (line ~ /[^[:space:]]/) recent[++n] = line
    }
    END {
      start = n - scan_lines + 1
      if (start < 1) start = 1
      for (i = n; i >= start; i--) {
        if (index(recent[i], "esc to interrupt") ||
            index(recent[i], "ctrl+c to interrupt") ||
            index(recent[i], "ctrl-c to interrupt")) {
          print "1"
          exit
        }
      }
      print "0"
    }'
}

ai_panes=$(
  {
    tmux list-panes -a -F "P	#{pane_pid}	#{pane_id}	#{session_name}:#{window_index}"
    ps -eo pid=,ppid=,command=
  } | awk -v allowlist="$allowlist" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function contains_ai_cmd(cmdline, lower_cmd, i, token) {
      lower_cmd = tolower(cmdline)
      for (i = 1; i <= allow_n; i++) {
        token = allow[i]
        if (token != "" && index(lower_cmd, token) > 0) return 1
      }
      return 0
    }
    BEGIN {
      allow_n = split(allowlist, raw, ",")
      for (i = 1; i <= allow_n; i++) allow[i] = tolower(trim(raw[i]))
    }
    $1 == "P" {
      pane_pid[$2] = $3
      pane_win[$2] = $4
      next
    }
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
      pid = $1
      ppid = $2
      cmdline = ""
      for (i = 3; i <= NF; i++) cmdline = cmdline (i > 3 ? " " : "") $i
      parent[pid] = ppid
      if (contains_ai_cmd(cmdline)) ai_pid[pid] = 1
      next
    }
    END {
      for (pid in ai_pid) {
        cur = pid
        for (i = 0; i < 120 && cur > 1; i++) {
          if (cur in pane_pid) {
            pane = pane_pid[cur]
            win = pane_win[cur]
            if (!(pane in emitted)) {
              print pane "\t" win
              emitted[pane] = 1
            }
            break
          }
          if (!(cur in parent)) break
          cur = parent[cur]
        }
      }
    }'
)

declare -A pane_state
declare -A window_state

while IFS=$'\t' read -r pane_id win_id; do
  [ -z "$pane_id" ] && continue
  if [ "$(pane_has_interrupt_marker "$pane_id")" = "1" ]; then
    pane_state["$pane_id"]="working"
    window_state["$win_id"]="working"
  else
    pane_state["$pane_id"]="idle"
    if [ -z "${window_state[$win_id]+x}" ]; then
      window_state["$win_id"]="idle"
    fi
  fi
done <<< "$ai_panes"

if [ "$mode" = "panes" ]; then
  for pane_id in "${!pane_state[@]}"; do
    printf "%s\t%s\n" "$pane_id" "${pane_state[$pane_id]}"
  done
else
  for win_id in "${!window_state[@]}"; do
    printf "%s\t%s\n" "$win_id" "${window_state[$win_id]}"
  done
fi
