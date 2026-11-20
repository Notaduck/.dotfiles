#!/usr/bin/env bash
# Bootstrap a Mac: Homebrew, Brewfile apps, stowed dotfiles and asdf runtimes.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_PACKAGES=(zsh nvim ghostty theme asdf bat btop tern omp)

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
    # Keep these real directories so stow links single files into them
    # instead of pointing the whole directory into this repo (Tern and omp
    # write databases, sockets and sessions next to their config).
    mkdir -p ~/.local/bin \
        "$HOME/Library/Application Support/Tern/plugins" \
        "$HOME/Library/Application Support/Tern/themes" \
        ~/.omp/agent/extensions ~/.omp/agent/themes
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

setup_touch_id_sudo() {
    # /etc/pam.d/sudo already includes sudo_local, which survives OS updates.
    # pam_reattach keeps Touch ID working for programs Tern's session daemon runs.
    local pam_file=/etc/pam.d/sudo_local
    if [[ -f "$pam_file" ]] && grep -q pam_tid.so "$pam_file"; then
        log "Touch ID for sudo already configured."
        return
    fi
    log "Enabling Touch ID for sudo (asks for your password once)..."
    sudo tee "$pam_file" > /dev/null <<'PAM'
# sudo_local: local config file which survives system update and is included for sudo
auth       optional       /opt/homebrew/lib/pam/pam_reattach.so ignore_ssh
auth       sufficient     pam_tid.so
PAM
}

apply_macos_defaults() {
    # Holding a key (j/k in nvim) repeats it instead of waiting for the
    # accent picker. Ghostty handles this itself; Tern needs the default.
    # Takes effect the next time Tern starts.
    defaults write so.stencil.tern ApplePressAndHoldEnabled -bool false
}

install_tern_settings() {
    # Tern saves settings.json by replacing the file, which would break a
    # stow link, so it is copied once instead. Copy changes back by hand:
    #   cp ~/Library/Application\ Support/Tern/settings.json ~/.dotfiles/tern-settings.json
    local target="$HOME/Library/Application Support/Tern/settings.json"
    if [[ ! -e "$target" ]]; then
        log "Installing Tern settings..."
        cp "$DOTFILES/tern-settings.json" "$target"
    fi
}

apply_theme() {
    log "Applying the default colour scheme..."
    "$DOTFILES/theme/.local/bin/theme" catppuccin-mocha
}

main() {
    install_homebrew
    install_applications
    apply_stow_configs
    install_tern_settings
    setup_touch_id_sudo
    apply_macos_defaults
    apply_theme
    setup_asdf
    log "Setup complete. Open a new shell to load ~/.zshrc."
}

main
