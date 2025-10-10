# Aliases
alias gl=glab
alias ghpr='gh pr create --head $(git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/\1/") --base'
alias whats_my_ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias vim=nvim
alias rm=trash

# Function to lowercase directory names
lower_case() {
  for dir in */; do
    mv "$dir" "$(echo "$dir" | tr 'A-Z' 'a-z')"
  done
}

# Editor
export EDITOR="nvim"

# Load environment variables from ~/.env
if [ -f "$HOME/.env" ]; then
  export $(grep -v '^#' "$HOME/.env" | xargs)
fi
# Load environment variables from ~/.env (safer for special characters)
if [ -f "$HOME/.env" ]; then
  set -a
  source "$HOME/.env"
  set +a
fi

# Path Exports (order matters)
export PATH="$HOME/go/bin:$PATH"                         # Go binaries
export PATH="/usr/local/opt/mysql-client/bin:$PATH"      # MySQL client
export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH"  # MySQL client 8.4
export PATH="$HOME/.local/bin:$PATH"                     # Local binaries
export PATH="$HOME/bin:$PATH"                            # Home bin
export PATH="$HOME/.bin:$PATH"                           # Home bin

# NPM global binaries (put before asdf so npm bins take priority)
export PATH="$(npm config get prefix)/bin:$PATH"
# NPM global binaries (put before asdf so npm bins take priority)
if command -v npm > /dev/null 2>&1; then
  export PATH="$(npm config get prefix)/bin:$PATH"
fi

# Cargo binaries
export PATH="$HOME/.cargo/bin:$PATH"

# Homebrew binaries
export PATH="/opt/homebrew/bin:$PATH"

# Zinit extras
export PATH="$HOME/.local/share/zinit/polaris/bin:$PATH"

# Ensure system paths are included
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# ASDF Version Manager
. "$(brew --prefix asdf)/libexec/asdf.sh"
fpath=($(brew --prefix asdf)/share/zsh/site-functions $fpath)
# ASDF Version Manager
if command -v asdf > /dev/null 2>&1; then
  . "$(brew --prefix asdf)/libexec/asdf.sh"
  fpath=($(brew --prefix asdf)/share/zsh/site-functions $fpath)
fi

# Initialize Zsh completion system
autoload -Uz compinit && compinit

# Zinit Plugin Manager Setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Zinit Plugins
zinit snippet OMZ::plugins/aws/aws.plugin.zsh
zinit light zdharma-continuum/history-search-multi-word
zinit light zsh-users/zsh-autosuggestions
zinit light KulkarniKaustubh/fzf-dir-navigator
zinit light zdharma-continuum/fast-syntax-highlighting

# Pure theme with async loading
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

# AWS Profile Prompt
aws_profile_prompt() {
  local profile=${AWS_PROFILE:-default}
  echo "%F{black}%K{yellow} AWS: $profile %k%f"
}
# AWS Profile Prompt (add to PROMPT or RPROMPT to display)
aws_profile_prompt() {
  local profile=${AWS_PROFILE:-default}
  echo "%F{black}%K{yellow} AWS: $profile %k%f"
}

# direnv integration
eval "$(direnv hook zsh)"
