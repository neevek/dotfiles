#!/usr/bin/env bash
# tmux-ai-detect: infer AI pane/window activity.
# Modes:
#   --mode panes   -> outputs "<pane_id>\t<state>"
#   --mode windows -> outputs "<session:window>\t<state>"
#
# States:
#   working: AI shows a running indicator, has shell children, or output is changing
#   idle:    AI pane has no running indicator, shell tools, or new output

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

# Keep cache state separate for each server, including after a server restart.
server_identity=$(tmux display-message -p '#{socket_path}:#{pid}' 2>/dev/null)
server_key=$(printf '%s' "$server_identity" | cksum | cut -d' ' -f1)
hash_file="${TMPDIR:-/tmp}/tmux-ai-detect-v3-${server_key}.tsv"
declare -A prev_hash prev_stamp prev_working
if [ -r "$hash_file" ]; then
  while IFS=$'\t' read -r _pid _hash _stamp _working; do
    [ -z "$_pid" ] && continue
    prev_hash["$_pid"]="$_hash"
    prev_stamp["$_pid"]="${_stamp:--}"
    prev_working["$_pid"]="${_working:-0}"
  done < "$hash_file"
fi

# Capture both the running indicator and a checksum above the input box.
# The input box (❯/› prompt + status lines) is stripped so user typing
# does not affect the hash — only program output changes it.
pane_content_snapshot() {
  local pane_id="$1" content snapshot
  content=$(tmux capture-pane -t "$pane_id" -p -S -50 2>/dev/null) || return 1
  snapshot=$(printf '%s\n' "$content" | LC_ALL=C awk '
    { lines[++n] = $0 }
    END {
      # Find the Claude ❯ or Codex › input prompt in the footer.
      cut = n
      for (i = n; i >= 1 && i >= n - 12; i--) {
        s = lines[i]
        sub(/^[[:space:]]+/, "", s)
        if (substr(s, 1, 3) == "\342\235\257" ||
            substr(s, 1, 3) == "\342\200\272") { cut = i - 1; break }
      }
      # Look for UI markers near the input rather than old transcript history.
      # These remain visible through network/tool output pauses.
      working = 0
      for (i = cut; i >= 1 && i >= cut - 12; i--) {
        s = lines[i]
        if (s ~ /^[[:space:]]*[^[:space:]]+[[:space:]].*\(.*esc to interrupt\)/ ||
            s ~ /^[[:space:]]*esc to interrupt([[:space:]]|$)/ ||
            s ~ /^[[:space:]]*(✢|✳|✶|✻|✽)[[:space:]].*(…|\.\.\.)/) {
          working = 1
          break
        }
      }
      print working
      for (i = 1; i <= cut; i++) print lines[i]
    }
  ')
  PANE_WORKING=${snapshot%%$'\n'*}
  PANE_HASH=$(printf '%s\n' "${snapshot#*$'\n'}" | cksum | cut -d' ' -f1)
}

ai_panes=$(
  {
    tmux list-panes -a -F "P	#{pane_pid}	#{pane_id}	#{session_name}:#{window_index}	g#{pane_output_generation}	h#{history_generation}	#{pane_width}	#{pane_height}"
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
      # Older servers expand unsupported fields to empty strings ("g").
      # PID, history generation and dimensions invalidate respawns/reflows.
      pane_stamp[$2] = ($5 ~ /^g[0-9]+$/ ? $2 ":" $5 ":" $6 ":" $7 ":" $8 : "-")
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
              print pane "\t" win "\t" active "\t" pane_stamp[cur]
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
declare -A current_hash current_stamp current_working

while IFS=$'\t' read -r pane_id win_id is_active stamp; do
  [ -z "$pane_id" ] && continue

  if [ "$is_active" = "1" ]; then
    # Shell children → actively executing tools.
    pane_state["$pane_id"]="working"
    window_state["$win_id"]="working"
  else
    # No children: avoid capturing unchanged panes on tmux 3.8+.
    # Changed output still goes through input-area filtering and hashing.
    prev="${prev_hash[$pane_id]-}"
    if [ "$stamp" != "-" ] && [ -n "$prev" ] &&
       [ "$stamp" = "${prev_stamp[$pane_id]-}" ]; then
      hash="$prev"
      working="${prev_working[$pane_id]:-0}"
    elif pane_content_snapshot "$pane_id"; then
      hash=$PANE_HASH
      working=$PANE_WORKING
    else
      # A disappearing pane or failed capture must not become cached output.
      continue
    fi
    current_hash["$pane_id"]="$hash"
    current_stamp["$pane_id"]="$stamp"
    current_working["$pane_id"]="$working"

    if [ "$working" = 1 ] || { [ -n "$prev" ] && [ "$hash" != "$prev" ]; }; then
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

# Persist snapshots and their pre-capture stamps atomically. Output arriving
# during capture changes the next stamp, so it is checked again on the next run.
hash_changed=0
[ "${#current_hash[@]}" -ne "${#prev_hash[@]}" ] && hash_changed=1
for pane_id in "${!current_hash[@]}"; do
  if [ "${current_hash[$pane_id]}" != "${prev_hash[$pane_id]-}" ] ||
     [ "${current_stamp[$pane_id]}" != "${prev_stamp[$pane_id]-}" ] ||
     [ "${current_working[$pane_id]}" != "${prev_working[$pane_id]-}" ]; then
    hash_changed=1; break
  fi
done
if [ "$hash_changed" -eq 1 ]; then
  hash_tmp="${hash_file}.tmp.$$"
  trap 'rm -f "$hash_tmp" 2>/dev/null' EXIT
  : > "$hash_tmp"
  for pane_id in "${!current_hash[@]}"; do
    printf "%s\t%s\t%s\t%s\n" "$pane_id" "${current_hash[$pane_id]}" \
      "${current_stamp[$pane_id]}" "${current_working[$pane_id]}" >> "$hash_tmp"
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
