function get_git_info() {
  local dir git_file git_dir head_line branch

  dir=$PWD

  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      git_dir="$dir/.git"
      break
    elif [[ -f "$dir/.git" ]]; then
      IFS= read -r git_file < "$dir/.git" || return
      case "$git_file" in
        'gitdir: '*)
          git_dir="${git_file#gitdir: }"
          [[ "$git_dir" != /* ]] && git_dir="$dir/$git_dir"
          break
          ;;
        *)
          return
          ;;
      esac
    fi
    dir=${dir:h}
  done

  [[ -n "$git_dir" && -r "$git_dir/HEAD" ]] || return

  IFS= read -r head_line < "$git_dir/HEAD" || return
  case "$head_line" in
    'ref: refs/heads/'*)
      branch="${head_line#ref: refs/heads/}"
      echo "(%{$fg_bold[green]%}${branch}%{$reset_color%})"
      ;;
  esac
}

PROMPT='[%{$fg[green]%}%n%{$reset_color%}@%{$fg[green]%}%M%{$reset_color%}:%{$fg[cyan]%}%~%{$reset_color%}$(get_git_info)]$ '

ZSH_THEME_GIT_PROMPT_REFIX="%{$fg_bold[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$reset_color%}"
