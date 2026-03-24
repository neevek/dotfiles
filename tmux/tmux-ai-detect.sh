#!/usr/bin/env bash
# tmux-ai-detect: infer AI pane/window activity.
# Modes:
#   --mode panes   -> outputs "<pane_id>\t<state>"
#   --mode windows -> outputs "<session:window>\t<state>"
#
# States:
#   working: AI process is actively executing (shell children or pane output changing)
#   idle:    pane is AI-associated but not producing output

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

# Content-delta state: hash of pane output (excluding input box) per invocation.
hash_file="${TMPDIR:-/tmp}/tmux-ai-detect-hash.tsv"
declare -A prev_hash
if [ -r "$hash_file" ]; then
  while IFS=$'\t' read -r _pid _hash; do
    [ -z "$_pid" ] && continue
    prev_hash["$_pid"]="$_hash"
  done < "$hash_file"
fi

# Capture pane content above the input box and return a checksum.
# The input box (❯ prompt + status lines) is stripped so user typing
# does not affect the hash — only program output changes it.
pane_content_hash() {
  local pane_id="$1"
  tmux capture-pane -t "$pane_id" -p -S -50 2>/dev/null | awk '
    { lines[++n] = $0 }
    END {
      # Find last prompt ❯ (U+276F = E2 9D AF) in bottom 12 lines.
      cut = n
      for (i = n; i >= 1 && i >= n - 12; i--) {
        s = lines[i]
        sub(/^[[:space:]]+/, "", s)
        if (substr(s, 1, 3) == "\342\235\257") { cut = i - 1; break }
      }
      for (i = 1; i <= cut; i++) print lines[i]
    }
  ' | cksum | cut -d' ' -f1
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

    function normalize_cmd(cmd, s) {
      s = trim(cmd)
      if (s == "") return ""
      gsub(/^.*[\/\\]/, "", s)
      return tolower(s)
    }

    function sanitize_token(token, s) {
      s = token
      gsub(/^[[:space:]\"\047]+/, "", s)
      gsub(/[[:space:]\"\047]+$/, "", s)
      while (s ~ /^[\[\](){}<>,;]/) s = substr(s, 2)
      while (s ~ /[\[\](){}<>,;]$/) s = substr(s, 1, length(s) - 1)
      return s
    }

    function is_wrapper_launcher(cmd) {
      return cmd == "node" || cmd == "npx" || cmd == "npm" || cmd == "pnpm" || \
             cmd == "yarn" || cmd == "bun" || cmd == "deno" || cmd == "python" || \
             cmd == "python3" || cmd == "uvx" || cmd == "pipx" || cmd == "env"
    }

    function candidate_from_cmdline_token(token, cleaned, candidate, at) {
      cleaned = sanitize_token(token)

      if (cleaned == "" || substr(cleaned, 1, 1) == "-" || index(cleaned, "://") > 0) {
        return ""
      }

      if (index(cleaned, "=") > 0) {
        return ""
      }

      candidate = normalize_cmd(cleaned)
      at = index(candidate, "@")
      if (at > 1) {
        candidate = substr(candidate, 1, at - 1)
      }

      if (candidate == "") return ""
      return candidate
    }

    function wrapper_entry_token(tokens, tok_n, idx, cleaned, prev_module_flag, looks_like_entry) {
      prev_module_flag = 0

      for (idx = 2; idx <= tok_n; idx++) {
        cleaned = sanitize_token(tokens[idx])
        if (cleaned == "") {
          continue
        }

        if (cleaned == "--") {
          prev_module_flag = 0
          continue
        }

        if (substr(cleaned, 1, 1) == "-") {
          prev_module_flag = (cleaned == "-m")
          continue
        }

        if (index(cleaned, "=") > 0) {
          prev_module_flag = 0
          continue
        }

        looks_like_entry = idx == 2 || prev_module_flag || index(cleaned, "/") > 0 || \
                           index(cleaned, "\\") > 0 || substr(cleaned, 1, 1) == "@" || \
                           cleaned ~ /\.js$/ || cleaned ~ /\.mjs$/ || cleaned ~ /\.cjs$/ || \
                           cleaned ~ /\.ts$/ || cleaned ~ /\.py$/

        prev_module_flag = 0
        if (looks_like_entry) {
          return tokens[idx]
        }
      }

      return ""
    }

    function contains_ai_cmd(cmdline, tok_n, exe, entry_tok, entry, i, j, n_candidates, token) {
      delete cmd_tokens
      tok_n = split(cmdline, cmd_tokens, /[[:space:]]+/)
      if (tok_n < 1) {
        return 0
      }

      delete candidates
      n_candidates = 0
      exe = candidate_from_cmdline_token(cmd_tokens[1])
      if (exe != "") {
        candidates[++n_candidates] = exe

        if (is_wrapper_launcher(exe)) {
          entry_tok = wrapper_entry_token(cmd_tokens, tok_n)
          if (entry_tok != "") {
            entry = candidate_from_cmdline_token(entry_tok)
            if (entry != "") {
              candidates[++n_candidates] = entry
            }
          }
        }
      }

      for (i = 1; i <= n_candidates; i++) {
        for (j = 1; j <= allow_n; j++) {
          token = allow[j]
          if (token != "" && candidates[i] == token) return 1
        }
      }

      return 0
    }

    function is_shell_cmd(cmdline,    toks, n, exe) {
      n = split(cmdline, toks, /[[:space:]]+/)
      if (n < 1) return 0
      exe = normalize_cmd(toks[1])
      return (exe == "sh" || exe == "bash" || exe == "zsh" || exe == "fish" || exe == "dash")
    }

    BEGIN {
      allow_n = split(allowlist, raw, ",")
      for (i = 1; i <= allow_n; i++) {
        allow[i] = normalize_cmd(raw[i])
      }
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
      n_children[ppid]++
      child_pid[ppid, n_children[ppid]] = pid
      cmd_by_pid[pid] = cmdline
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
              active = 0
              for (j = 1; j <= n_children[pid]; j++) {
                kid = child_pid[pid, j]
                if (kid in cmd_by_pid && is_shell_cmd(cmd_by_pid[kid])) {
                  active = 1
                  break
                }
              }
              print pane "\t" win "\t" active
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
declare -A current_hash

while IFS=$'\t' read -r pane_id win_id is_active; do
  [ -z "$pane_id" ] && continue

  if [ "$is_active" = "1" ]; then
    # Shell children → actively executing tools.
    pane_state["$pane_id"]="working"
    window_state["$win_id"]="working"
  else
    # No children — check if pane output changed since last invocation.
    hash=$(pane_content_hash "$pane_id")
    current_hash["$pane_id"]="$hash"
    prev="${prev_hash[$pane_id]-}"

    if [ -n "$prev" ] && [ "$hash" != "$prev" ]; then
      pane_state["$pane_id"]="working"
      window_state["$win_id"]="working"
    else
      pane_state["$pane_id"]="idle"
      if [ -z "${window_state[$win_id]+x}" ]; then
        window_state["$win_id"]="idle"
      fi
    fi
  fi
done <<< "$ai_panes"

# Persist hashes for next invocation (skip if unchanged).
hash_changed=0
for pane_id in "${!current_hash[@]}"; do
  if [ "${current_hash[$pane_id]}" != "${prev_hash[$pane_id]-}" ]; then
    hash_changed=1; break
  fi
done
if [ "$hash_changed" -eq 1 ]; then
  hash_tmp="${hash_file}.tmp.$$"
  trap 'rm -f "$hash_tmp" 2>/dev/null' EXIT
  for pane_id in "${!current_hash[@]}"; do
    printf "%s\t%s\n" "$pane_id" "${current_hash[$pane_id]}" >> "$hash_tmp"
  done
  mv -f "$hash_tmp" "$hash_file" 2>/dev/null || true
fi

if [ "$mode" = "panes" ]; then
  for pane_id in "${!pane_state[@]}"; do
    printf "%s\t%s\n" "$pane_id" "${pane_state[$pane_id]}"
  done
else
  for win_id in "${!window_state[@]}"; do
    printf "%s\t%s\n" "$win_id" "${window_state[$win_id]}"
  done
fi
