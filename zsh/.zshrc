# PATH is built in .zprofile. A non-login shell whose parent never ran it (a
# terminal spawned straight from a GUI app) picks it up here.
[[ -o login ]] || (( ${path[(Ie)$HOME/.local/bin]} )) || source "$HOME/.zprofile"

# Aliases (rm is at the bottom, see there)
alias gl=glab
alias vim=nvim

# Function to lowercase directory names
lower_case() {
  for dir in */; do
    mv "$dir" "$(echo "$dir" | tr 'A-Z' 'a-z')"
  done
}

# Editor, and vi keys on the command line. zsh would pick vi mode anyway
# because EDITOR contains "vi"; say so explicitly. KEYTIMEOUT is the wait after
# Esc in 1/100 s: 1 makes the switch to normal mode instant instead of 0.4 s.
export EDITOR="nvim"
bindkey -v
KEYTIMEOUT=1

# Colour scheme: `theme <name>` switches Ghostty, Neovim, bat, omp and Tern together
# (see theme/.local/bin/theme). bat only reads BAT_THEME at startup, so the
# wrapper re-exports it for the current shell after a switch.
[ -r "$HOME/.local/state/theme/bat" ] && export BAT_THEME="$(<"$HOME/.local/state/theme/bat")"
theme() {
  command theme "$@" || return
  [ -r "$HOME/.local/state/theme/bat" ] && export BAT_THEME="$(<"$HOME/.local/state/theme/bat")"
}

# History: one big file shared by every tab, pane and session. Each command
# is appended the moment it runs; Ctrl-R re-reads the file (see bottom) so it
# searches everything, while Up-arrow stays local to the current shell.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt EXTENDED_HISTORY       # store timestamp + duration
setopt INC_APPEND_HISTORY     # write immediately, not on shell exit
setopt HIST_FCNTL_LOCK        # safe concurrent writes from many shells
setopt HIST_IGNORE_ALL_DUPS   # keep only the latest copy of a command
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE      # prefix a command with a space to keep it out
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY            # !! / !$ expand into the line instead of running

# Secrets live in the login Keychain, not in the environment, so they are not
# handed to every child process. `secret NAME` prints one, e.g.
#   STRIPE_API_KEY=$(secret STRIPE_CLI_READ_ONLY_KEY) stripe ...
# Add or replace one (prompts for the value):
#   security add-generic-password -U -a "$USER" -s NAME -w
secret() {
  security find-generic-password -a "$USER" -s "$1" -w
}

# Completion. omp only ships a generator, so its output is cached in fpath and
# regenerated when the binary is newer than the cached copy.
typeset -U fpath
zsh_comp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
if (( $+commands[omp] )) && [[ ! "$zsh_comp_cache/_omp" -nt $commands[omp] ]]; then
  mkdir -p "$zsh_comp_cache"
  omp completions zsh >| "$zsh_comp_cache/_omp" 2> /dev/null
fi
fpath=("$zsh_comp_cache" $fpath)

# Reuse the generated completion dump. Rebuild it after the shell config or a
# completion directory changes, then use the fast path thereafter.
autoload -Uz compinit
zcompdump_path="${ZDOTDIR:-$HOME}/.zcompdump"
if [ -s "$zcompdump_path" ] \
  && [ "$zcompdump_path" -nt "$HOME/.zshrc" ] \
  && [ "$zcompdump_path" -nt /opt/homebrew/share/zsh/site-functions ] \
  && [ "$zcompdump_path" -nt "$zsh_comp_cache" ]; then
  compinit -C -d "$zcompdump_path"
else
  compinit -d "$zcompdump_path"
fi
unset zcompdump_path zsh_comp_cache

zstyle ':completion:*' menu select                      # Tab again to walk the list
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}'  # exact first, then ignore case
zstyle ':completion:*' list-colors ''

# aws ships a bash-style completer.
if (( $+commands[aws_completer] )); then
  autoload -Uz bashcompinit && bashcompinit
  complete -C aws_completer aws
fi

# Prompt and plugins are Homebrew formulae (see Brewfile); `brew upgrade`
# updates them.
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -Uz promptinit && promptinit
prompt pure

# Keep fast-syntax-highlighting after pure: pure registers ZLE hooks through
# add-zle-hook-widget. If a terminal integration (Tern) already installed that
# dispatcher, loading FSH first makes pure re-add FSH's wrapper as a hook,
# which calls the dispatcher again -> "zle-line-finish: maximum nested
# function level reached" on every Enter.
source /opt/homebrew/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# fzf: Ctrl-R history search, Ctrl-T file picker, Alt-C cd. Ctrl-R first pulls in
# commands other shells have written since this one started. Enter runs the
# picked command straight away; Tab drops it on the prompt for editing instead.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
  _fzf_hist_edit_flag="${TMPDIR:-/tmp}/fzf-hist-edit.$$"
  export FZF_CTRL_R_OPTS="--bind 'tab:execute-silent(touch ${_fzf_hist_edit_flag})+accept' --header 'enter: run · tab: edit'"
  fzf-history-widget-all() {
    command rm -f "$_fzf_hist_edit_flag"
    fc -RI
    zle fzf-history-widget || return
    if [[ -e $_fzf_hist_edit_flag ]]; then
      command rm -f "$_fzf_hist_edit_flag"
    elif [[ -n $BUFFER && -n ${history[(Re)$BUFFER]} ]]; then
      zle accept-line
    fi
  }
  zle -N fzf-history-widget-all
  bindkey -M emacs '^R' fzf-history-widget-all
  bindkey -M viins '^R' fzf-history-widget-all
  bindkey -M vicmd '^R' fzf-history-widget-all
fi

# direnv integration
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# zoxide takes over cd: `cd foo` still enters ./foo, and otherwise jumps to the
# best-ranked directory matching "foo"; `cdi` picks one interactively.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ghcpr <num> -> checkout PR in a worktree + new Tern split beside this pane
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
  if [[ -n "$TERN_PANE" ]]; then
    tern split @focused right --cwd "$dir" -- zsh -c "gh pr checkout $pr; exec zsh" > /dev/null
  else
    echo "not inside Tern; worktree ready at $dir"
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

# rm moves things to the Trash instead of deleting them. /usr/bin/trash rejects
# rm's flags, so they are dropped (directories need no -r); -f keeps its
# "missing files are fine" meaning. Hard delete: `command rm` or /bin/rm.
#
# Keep the alias last in this file. An alias is expanded where a function is
# defined, so anything defined after it that calls rm on its own temp files
# would send them to the Trash (and fail on -f before this wrapper existed).
rm_to_trash() {
  local -a files present
  local arg force
  while (( $# )); do
    arg=$1
    shift
    case $arg in
      --) files+=("$@"); break ;;
      -f*|-[!-]*f*|--force) force=1 ;;
      -?*) ;;
      *) files+=("$arg") ;;
    esac
  done
  if [[ -n $force ]]; then
    for arg in "${files[@]}"; do
      [[ -e $arg || -L $arg ]] && present+=("$arg")
    done
    files=("${present[@]}")
  fi
  if (( ! $#files )); then
    [[ -n $force ]] && return 0
    print -u2 "usage: rm [-rf] file ..."
    return 64
  fi
  trash "${files[@]/#-/./-}"
}
alias rm=rm_to_trash
