#!/usr/bin/env bash
# Bootstrap a Mac: Homebrew, Brewfile apps, stowed dotfiles and asdf runtimes.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=(zsh nvim tmux ghostty asdf bat btop wallpapers)

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        log "Updating Homebrew..."
        brew update
    fi
}

install_applications() {
    log "Installing Brewfile..."
    if ! brew bundle --file="$DOTFILES/Brewfile"; then
        log "Warning: some Brewfile entries failed to install."
    fi
}

apply_stow_configs() {
    cd "$DOTFILES"
    for pkg in "${STOW_PACKAGES[@]}"; do
        log "Stowing ${pkg}..."
        # Fails on conflicts with existing real files; move those aside first.
        stow -R "$pkg"
    done
}

setup_asdf() {
    log "Installing asdf plugins and versions from ~/.tool-versions..."
    cut -d' ' -f1 ~/.tool-versions | while read -r plugin; do
        asdf plugin list | grep -qx "$plugin" || asdf plugin add "$plugin"
    done
    (cd ~ && asdf install)
}

main() {
    install_homebrew
    install_applications
    apply_stow_configs
    setup_asdf
    log "Setup complete. Open a new shell to load ~/.zshrc."
}

main
