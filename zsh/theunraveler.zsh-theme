# Comment

PROMPT='%{$fg[red]%}[%c] %{$reset_color%}'

RPROMPT='%{$fg[red]%}$(git_prompt_info)%{$reset_color%} $(git_prompt_status)%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX=""
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[cyan]%} ✈"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[red]%} ✭"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} ✗"
#ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%} ➦"
#ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[red]%} ✂"
#ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[grey]%} ✱"
