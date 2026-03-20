#!/usr/bin/env bash
# Set AI-aware window tab colors after tmux2k loads.
# Called once via run-shell in tmux.conf (after tpm).

L=$(printf '\xee\x82\xb6')  # U+E0B6 powerline left half-circle
R=$(printf '\xee\x82\xb4')  # U+E0B4 powerline right half-circle
SBG="#000000"                # status bar background

# 3-way conditional helper: working / idle / default
c() { echo "#{?#{==:#{@ai_state},working},$1,#{?#{==:#{@ai_state},idle},$2,$3}}"; }

# --- Non-current windows ---
BG=$(c '#e65c00' '#554488' '#3f3f4f')   # working=orange, idle=purple, normal=gray
FG=$(c '#ffffff' '#ccccdd' '#ffffff')

tmux set -g window-status-format \
  "#[fg=${BG},bg=${SBG}]${L}#[bg=${BG}]#{?window_flags,#[fg=#ff1f1f]#{window_flags},}#[fg=${FG}]#I:#W#[fg=${BG},bg=${SBG}]${R}"

# --- Current window ---
BG=$(c '#ff7700' '#7766aa' '#1688f0')   # working=bright orange, idle=bright purple, normal=blue
FG=$(c '#000000' '#ffffff' '#000000')

tmux set -g window-status-current-format \
  "#[fg=${BG},bg=${SBG}]${L}#[bg=${BG}]#{?window_flags,#[fg=#ccffcc]#{window_flags},}#[fg=${FG}]#I:#W#[fg=${BG},bg=${SBG}]${R}"
