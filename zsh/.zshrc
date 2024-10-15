# Aliases
alias gl=glab
alias ghpr='gh pr create --head "$(git branch 2>/dev/null | sed -n "s/* //p")" --base'
alias whats_my_ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias vim=nvim
alias rm=trash
alias discord='vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland'
alias gh='/bin/gh'
alias task="go-task"

# Path Exports
export PATH="$HOME/go/bin:/usr/local/opt/mysql-client/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$(go env GOBIN):$(go env GOPATH)/bin"

# Load Environment Variables Securely
if [[ -f "$HOME/.env" ]]; then
    export $(grep -v '^#' "$HOME/.env" | xargs)
fi

# Initialize Zsh Completion System
autoload -Uz compinit && compinit

# Zinit Plugin Manager Setup
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# Load Plugins with Zinit
zinit light zdharma-continuum/history-search-multi-word
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit snippet https://gist.githubusercontent.com/hightemp/5071909/raw/
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure
zinit ice atload"zpcdreplay" atclone "./zplug.zsh"
zinit light g-plane/zsh-yarn-autocompletions

# Completion Style
zstyle ':completion:*' menu select

# Initialize asdf for mac
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     
        machine=Linux
        # Initialize asdf for Linux
        . /opt/asdf-vm/asdf.sh
        ;;
    Darwin*)    
        machine=Mac
        # Initialize asdf for macOS
        . /usr/local/opt/asdf/libexec/asdf.sh
        ;;
    # CYGWIN*)    
    #     machine=Cygwin
    #     ;;
    # MINGW*)     
    #     machine=MinGw
    #     ;;
    # MSYS_NT*)   
    #     machine=Git
    #     ;;
    *)          
        machine="UNKNOWN:${unameOut}"
        ;;
esac
