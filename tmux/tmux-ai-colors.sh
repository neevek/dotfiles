#!/usr/bin/env bash
# Set AI-aware window tab colors after tmux2k loads.
# Called once via run-shell in tmux.conf (after tpm).

set -euo pipefail

readonly L=$'\xee\x82\xb6'   # U+E0B6 powerline left half-circle
readonly R=$'\xee\x82\xb4'   # U+E0B4 powerline right half-circle
readonly SBG="#000000"       # status bar background

# Muted state surfaces keep busy window lists calm. The selected window uses
# the same state hue with a lighter surface; selection never changes its meaning.
# working = cyan (activity), idle = amber (ready for input), ordinary = slate.
readonly NON_CURRENT_BG="#{?#{==:#{@ai_state},working},#16343b,#{?#{==:#{@ai_state},idle},#382e1e,#242833}}"
readonly NON_CURRENT_FG="#{?#{==:#{@ai_state},working},#79dce8,#{?#{==:#{@ai_state},idle},#e8bd75,#b3bccb}}"
readonly CURRENT_BG="#{?#{==:#{@ai_state},working},#28515a,#{?#{==:#{@ai_state},idle},#59462b,#3b4963}}"
readonly CURRENT_FG="#f2f5fa"
readonly STATE_FG="#{?#{==:#{@ai_state},working},#79dce8,#{?#{==:#{@ai_state},idle},#e8bd75,#b3bccb}}"
# A simple activity mark supplements cyan; idle tabs use color alone.
readonly STATE_MARK="#{?#{==:#{@ai_state},working},~ ,}"
# Only actionable tmux alerts get a flag; selection (*) and last-window (-)
# already have visual context and otherwise clutter the start of each label.
readonly ALERT="#{?window_bell_flag, !,#{?window_activity_flag, +,}}"

readonly WINDOW_STATUS_FORMAT="#[none,fg=${NON_CURRENT_BG},bg=${SBG}]${L}#[bg=${NON_CURRENT_BG},fg=${STATE_FG}] ${STATE_MARK}#[fg=${NON_CURRENT_FG}]#I #W#[fg=#f38ba8]${ALERT} #[none,fg=${NON_CURRENT_BG},bg=${SBG}]${R}#[default]"
readonly WINDOW_STATUS_CURRENT_FORMAT="#[none,fg=${CURRENT_BG},bg=${SBG}]${L}#[bg=${CURRENT_BG},fg=${STATE_FG},bold] ${STATE_MARK}#[fg=${CURRENT_FG}]#I #W#[fg=#f38ba8]${ALERT} #[none,fg=${CURRENT_BG},bg=${SBG}]${R}#[default]"

current_window_status_format="$(tmux show -gv window-status-format 2>/dev/null || true)"
current_window_status_current_format="$(tmux show -gv window-status-current-format 2>/dev/null || true)"

if [ "${current_window_status_format}" = "${WINDOW_STATUS_FORMAT}" ] &&
  [ "${current_window_status_current_format}" = "${WINDOW_STATUS_CURRENT_FORMAT}" ]; then
  exit 0
fi

tmux set -g window-status-format "${WINDOW_STATUS_FORMAT}" \;\
  set -g window-status-current-format "${WINDOW_STATUS_CURRENT_FORMAT}"
