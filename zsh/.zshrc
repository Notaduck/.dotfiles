

alias gl=glab
alias ghpr='gh pr create --head $(git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/\1/") --base'
alias whats_my_ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias vim=nvim

# Path Exports
export PATH="$HOME/go/bin:/usr/local/opt/mysql-client/bin:$PATH"

# GitHub Personal Access Token (Load Securely)
if [ -f "$HOME/.env" ]; then
    export $(grep -v '^#' "$HOME/.env" | xargs)
fi

# Initialize Zsh completion system
autoload -Uz compinit && compinit

### Zinit Plugin Manager Setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load plugins
zinit light zdharma-continuum/history-search-multi-word
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit snippet https://gist.githubusercontent.com/hightemp/5071909/raw/

# Load pure theme with async
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

# Yarn autocomplete
zinit ice atload"zpcdreplay" atclone'./zplug.zsh'
zinit light g-plane/zsh-yarn-autocompletions

# Completion style
zstyle ':completion:*' menu select

# Created by `pipx` on 2024-08-23 08:14:57
export PATH="$PATH:/Users/Daniel_1/.local/bin"


. /usr/local/opt/asdf/libexec/asdf.sh
