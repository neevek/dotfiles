#!/usr/bin/env bash
# Set AI-aware window tab colors after tmux2k loads.
# Called once via run-shell in tmux.conf (after tpm).

set -euo pipefail

readonly L=$'\xee\x82\xb6'   # U+E0B6 powerline left half-circle
readonly R=$'\xee\x82\xb4'   # U+E0B4 powerline right half-circle
readonly SBG="#000000"       # status bar background

# 3-way conditionals, expanded once to avoid command-substitution overhead.
readonly NON_CURRENT_BG="#{?#{==:#{@ai_state},working},#e65c00,#{?#{==:#{@ai_state},idle},#554488,#3f3f4f}}"  # working=orange, idle=purple, normal=gray
readonly NON_CURRENT_FG="#{?#{==:#{@ai_state},working},#ffffff,#{?#{==:#{@ai_state},idle},#ccccdd,#ffffff}}"
readonly CURRENT_BG="#{?#{==:#{@ai_state},working},#ff7700,#{?#{==:#{@ai_state},idle},#7766aa,#1688f0}}"      # working=bright orange, idle=bright purple, normal=blue
readonly CURRENT_FG="#{?#{==:#{@ai_state},working},#000000,#{?#{==:#{@ai_state},idle},#ffffff,#000000}}"

readonly WINDOW_STATUS_FORMAT="#[fg=${NON_CURRENT_BG},bg=${SBG}]${L}#[bg=${NON_CURRENT_BG}]#{?window_flags,#[fg=#ff1f1f]#{window_flags},}#[fg=${NON_CURRENT_FG}]#I:#W#[fg=${NON_CURRENT_BG},bg=${SBG}]${R}"
readonly WINDOW_STATUS_CURRENT_FORMAT="#[fg=${CURRENT_BG},bg=${SBG}]${L}#[bg=${CURRENT_BG}]#{?window_flags,#[fg=#ccffcc]#{window_flags},}#[fg=${CURRENT_FG}]#I:#W#[fg=${CURRENT_BG},bg=${SBG}]${R}"

current_window_status_format="$(tmux show -gv window-status-format 2>/dev/null || true)"
current_window_status_current_format="$(tmux show -gv window-status-current-format 2>/dev/null || true)"

if [ "${current_window_status_format}" = "${WINDOW_STATUS_FORMAT}" ] &&
  [ "${current_window_status_current_format}" = "${WINDOW_STATUS_CURRENT_FORMAT}" ]; then
  exit 0
fi

tmux set -g window-status-format "${WINDOW_STATUS_FORMAT}" \;\
  set -g window-status-current-format "${WINDOW_STATUS_CURRENT_FORMAT}"
