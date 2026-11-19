eval "$(/opt/homebrew/bin/brew shellenv zsh)"

# PATH is built here rather than in .zshrc so that login shells which never go
# interactive (`zsh -lc`, editors, agents) resolve the same binaries. asdf
# 0.16+ is a standalone binary that only needs its shims directory; it goes
# ahead of Homebrew so .tool-versions wins over Homebrew's own node.
typeset -U path
path=(
  "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
  "$HOME/.local/bin"
  "$HOME/go/bin"
  $path
)
