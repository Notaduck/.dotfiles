alias gl=glab
alias ghpr='gh pr create --head $(git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/\1/") --base'
alias whats_my_ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias vim=nvim

# Path Exports
export PATH="$HOME/go/bin:/usr/local/opt/mysql-client/bin:$PATH"
# export PATH="$PATH:$(yarn global bin)"

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


aws_profile_prompt() {
    # Get the current AWS profile
    local profile=${AWS_PROFILE:-default}

    # Style the output with colors
    # You can customize the colors here
    echo "%F{black}%K{yellow} AWS: $profile %k%f"
}

zinit snippet OMZ::plugins/aws/aws.plugin.zsh

# zinit ice svn; zinit light ohmyzsh/ohmyzsh
#
# zinit light ohmyzsh/ohmyzsh plugins/aws

# Load plugins
zinit light zdharma-continuum/history-search-multi-word
zinit light zsh-users/zsh-autosuggestions
zinit light  KulkarniKaustubh/fzf-dir-navigator
zinit light zdharma-continuum/fast-syntax-highlighting

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


# . /usr/local/opt/agccsdf/libexec/asdf.sh
# export PATH="/opt/homebrew/opt/mysql/bin:$PATH"
export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH"



# if [ "$TMUX" = "" ]; then tmux; fi

. /opt/homebrew/opt/asdf/libexec/asdf.sh
export PATH=/Users/dagu/.asdf/shims:/opt/homebrew/opt/asdf/libexec/bin:/usr/local/opt/mysql-client@8.4/bin:/Users/dagu/go/bin:/usr/local/opt/mysql-client/bin:/usr/local/opt/mysql-client@8.4/bin:/Users/dagu/.local/share/zinit/polaris/bin:/Users/dagu/go/bin:/usr/local/opt/mysql-client/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin::/Users/Daniel_1/.local/bin::/Users/Daniel_1/.local/bin:/opt/homebrew/bin


eval "$(direnv hook zsh)"
