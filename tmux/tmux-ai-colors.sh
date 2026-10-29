#!/usr/bin/env bash
# Set AI-aware window tab colors after tmux2k loads.
# Called once via run-shell in tmux.conf (after tpm).

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/tmux-ai-palette.sh"

readonly L=$'\xee\x82\xb6'   # U+E0B6 powerline left half-circle
readonly R=$'\xee\x82\xb4'   # U+E0B4 powerline right half-circle
readonly SBG="#000000"       # status bar background

# Muted state surfaces keep busy window lists calm. The selected window uses
# the same state hue with a lighter surface; selection never changes its meaning.
# All AI tabs use cyan; only the icon changes with activity or completion.
readonly NON_CURRENT_BG="#{?@ai_state,#16343b,#242833}"
readonly NON_CURRENT_FG="#{?@ai_state,${TMUX_AI_WORKING_FG},#b3bccb}"
readonly CURRENT_BG="#{?@ai_state,#28515a,#3b4963}"
readonly CURRENT_FG="#f2f5fa"
readonly STATE_FG="#{?@ai_finished,${TMUX_AI_FINISHED_FG},${TMUX_AI_WORKING_FG}}"
# Native tmux animation advances every 200 ms without a process per frame.
# Idle tabs use Nerd Font nf-md-robot (U+F06A9), red for unseen completion.
readonly STATE_MARK="#{?@ai_state,#{?#{==:#{@ai_state},working},#{A/2:⠋,⠙,⠹,⠸,⠼,⠴,⠦,⠧,⠇,⠏},󰚩} ,}"

readonly WINDOW_STATUS_FORMAT="#[none,fg=${NON_CURRENT_BG},bg=${SBG}]${L}#[bg=${NON_CURRENT_BG},fg=${STATE_FG}] ${STATE_MARK}#[fg=${NON_CURRENT_FG}]#I #W #[none,fg=${NON_CURRENT_BG},bg=${SBG}]${R}#[default]"
readonly WINDOW_STATUS_CURRENT_FORMAT="#[none,fg=${CURRENT_BG},bg=${SBG}]${L}#[bg=${CURRENT_BG},fg=${STATE_FG},bold] ${STATE_MARK}#[fg=${CURRENT_FG}]#I #W #[none,fg=${CURRENT_BG},bg=${SBG}]${R}#[default]"

current_window_status_format="$(tmux show -gv window-status-format 2>/dev/null || true)"
current_window_status_current_format="$(tmux show -gv window-status-current-format 2>/dev/null || true)"

if [ "${current_window_status_format}" = "${WINDOW_STATUS_FORMAT}" ] &&
  [ "${current_window_status_current_format}" = "${WINDOW_STATUS_CURRENT_FORMAT}" ]; then
  exit 0
fi

tmux set -g window-status-format "${WINDOW_STATUS_FORMAT}" \;\
  set -g window-status-current-format "${WINDOW_STATUS_CURRENT_FORMAT}"
