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

jwt-decode() {
  jq -R 'split(".") |.[0:2] | map(@base64d) | map(fromjson)' <<< $1
}

# Editor
export EDITOR="nvim"

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

# NPM global binaries
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

# Avoid compounding duplicate PATH entries in nested tmux shells.
typeset -U path PATH

# asdf 0.16+ is a standalone binary: put its shims on PATH and add completions.
if command -v asdf > /dev/null 2>&1; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi
if [ -d /opt/homebrew/opt/asdf/share/zsh/site-functions ]; then
  fpath=(/opt/homebrew/opt/asdf/share/zsh/site-functions $fpath)
fi

# Reuse the generated completion dump. Rebuild it after the shell config or
# Homebrew completion directory changes, then use the fast path thereafter.
autoload -Uz compinit
zcompdump_path="${ZDOTDIR:-$HOME}/.zcompdump"
if [ -s "$zcompdump_path" ] \
  && [ "$zcompdump_path" -nt "$HOME/.zshrc" ] \
  && [ "$zcompdump_path" -nt /opt/homebrew/share/zsh/site-functions ]; then
  compinit -C -d "$zcompdump_path"
else
  compinit -d "$zcompdump_path"
fi
unset zcompdump_path

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

# AWS Profile Prompt (add to PROMPT or RPROMPT to display)
aws_profile_prompt() {
  local profile=${AWS_PROFILE:-default}
  echo "%F{black}%K{yellow} AWS: $profile %k%f"
}

# direnv integration
eval "$(direnv hook zsh)"

# Track frequently used directories for the on-demand Sesh project picker.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# ghcpr <num> -> checkout PR in a worktree + new tmux pane
ghcpr() {
  if [[ "$1" != <-> ]]; then
    echo "usage: ghcpr <pr-number>" >&2
    return 1
  fi
  local pr=$1
  local root
  root=$(command git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; return 1 }
  local dir="$root/.worktrees/pr-$pr"
  if [[ ! -d "$dir" ]]; then
    command git -C "$root" fetch origin "pull/$pr/head" || return
    grep -qx '.worktrees/' "$root/.git/info/exclude" 2>/dev/null || echo '.worktrees/' >> "$root/.git/info/exclude"
    command git -C "$root" worktree add --detach "$dir" FETCH_HEAD || return
  fi
  if [[ -n "$TMUX" ]]; then
    tmux split-window -h -c "$dir" "gh pr checkout $pr; exec zsh"
  else
    echo "not inside tmux; worktree ready at $dir"
    ( cd "$dir" && gh pr checkout "$pr" )
  fi
}

# warn when a misnamed asdf version file would be silently ignored
asdf_typo_check() {
  local f
  for f in .tool-version .toolversions .tool_versions .asdfrc.local; do
    [[ -e $f ]] && echo "⚠ '$f' is ignored by asdf — rename it to '.tool-versions'" >&2
  done
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd asdf_typo_check
asdf_typo_check
