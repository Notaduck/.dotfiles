alias gl=glab
alias ghpr='gh pr create --head $(git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/\1/") --base'
alias whats_my_ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias vim=nvim
alias rm=trash
alias lower_case="for dir in */; do mv "$dir" "$(echo $dir | tr 'A-Z' 'a-z')"; done

export EDITOR="nvim"
"

# Path Exports
# Add each component separately for better maintainability
export PATH="$HOME/go/bin:$PATH"                        # Go binaries
export PATH="/usr/local/opt/mysql-client/bin:$PATH"     # MySQL client
export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH" # MySQL client 8.4
export PATH="$HOME/.local/bin:$PATH"                    # Local binaries
export PATH="$HOME/bin:$PATH"                           # Home bin directory
export PATH="$HOME/.bin:$PATH"                           # Home bin directory
# export PATH="$PATH:$(yarn global bin)"                # Yarn global binaries (commented)

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
# ASDF version manager
. "$(brew --prefix asdf)/libexec/asdf.sh"

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Add ASDF shims to PATH
export PATH="$HOME/.asdf/shims:$PATH"

# Add Zinit extras to PATH
export PATH="$HOME/.local/share/zinit/polaris/bin:$PATH"

# Ensure system paths are included
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH"

# Add the correct line:
# Add npm global binaries to PATH
export PATH="$(npm config get prefix)/bin:$PATH"

# Add Cargo binaries to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Print PATH components for debugging (uncomment to use)
# echo "PATH components:"
# echo $PATH | tr ':' '\n'



eval "$(direnv hook zsh)"

export PATH="$(npm config get prefix)/bin:$PATH"


