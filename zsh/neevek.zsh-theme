function get_git_info() {
  br=$(git branch 2> /dev/null | awk -F'[ )]' '/^\*/{br=$2}/HEAD detached/{br=$(NF-1)}END{print br}')
  mcount=$(git status --porcelain 2> /dev/null | grep -cv '^?')
  if [[ $mcount -ne 0 ]]; then
    echo -e "(%{$fg_bold[green]%}$br%{$reset_color%}|%{$fg[red]%}$mcount%{$reset_color%})"
  elif [[ ! -z "$br" ]]; then
    echo -e "(%{$fg_bold[green]%}$br%{$reset_color%})"
  fi
}

PROMPT='[%n%{$reset_color%}@%{$reset_color%}%{$fg[cyan]%}%~%{$reset_color%}$(get_git_info)%{$reset_color%}]$ '

ZSH_THEME_GIT_PROMPT_REFIX="%{$fg_bold[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$reset_color%}"
