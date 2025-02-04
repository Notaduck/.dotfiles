#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if an unset variable is used, or if any command in a pipeline fails.
set -euo pipefail

# A simple logging function with timestamps.
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add Homebrew to PATH for the current and future sessions (adjust path if needed)
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        log "Homebrew is already installed. Updating Homebrew..."
        brew update
    fi
}

define_app_lists() {
    BREW_PACKAGES=(
        yarn
        git
        wget
        httpie
        neovim
        docker
        tmux
        fzf
        asdf
        coreutils
        stow
    )

    CASK_APPS=(
        monitorcontrol
        visual-studio-code
        postman
        raycast
        alacritty
        obsidian
    )
}

create_brewfile() {
    local BREWFILE_PATH="$HOME/Brewfile"
    log "Creating Brewfile at ${BREWFILE_PATH}..."

    {
        echo "# Brewfile generated by setup_mac.sh"
        echo ""

        if [ ${#BREW_PACKAGES[@]} -ne 0 ]; then
            echo "# Homebrew Packages"
            for pkg in "${BREW_PACKAGES[@]}"; do
                echo "brew \"$pkg\""
            done
            echo ""
        fi

        if [ ${#CASK_APPS[@]} -ne 0 ]; then
            echo "# Homebrew Cask Applications"
            for app in "${CASK_APPS[@]}"; do
                echo "cask \"$app\""
            done
            echo ""
        fi
    } > "$BREWFILE_PATH"

    log "Brewfile created successfully."
}

install_applications() {
    log "Installing applications from Brewfile..."
    # Temporarily disable 'exit on error' for brew bundle so we can capture failures.
    set +e
    brew bundle --file="$HOME/Brewfile"
    BUNDLE_STATUS=$?
    set -e

    if [ $BUNDLE_STATUS -ne 0 ]; then
        log "Warning: Some Brewfile dependencies failed to install."
        log "If you see errors about already-installed applications, you can ignore them."
    else
        log "All Brewfile applications installed successfully."
    fi
}

setup_asdf() {
    if ! command -v asdf &> /dev/null; then
        log "asdf not found. Skipping asdf plugin installations."
        return
    fi

    log "Setting up asdf plugins..."
    # Add golang plugin if not already added.
    if ! asdf plugin-list | grep -q '^golang$'; then
        asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
    fi
    asdf install golang latest

    # Add nodejs plugin if not already added.
    if ! asdf plugin-list | grep -q '^nodejs$'; then
        asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
    fi
    asdf install nodejs latest

    log "asdf setup complete."
}

apply_stow_configs() {
    # Only run stow if the command is available.
    if ! command -v stow &> /dev/null; then
        log "stow not found. Skipping configuration deployment."
        return
    fi

    for dir in zsh nvim tmux; do
        if [ -d "./${dir}" ]; then
            log "Applying stow configuration for ${dir}..."
            # The '-R' flag reintegrates files, but you can adjust as needed.
            stow -R "$dir"
        else
            log "Directory ./${dir} not found. Skipping ${dir}."
        fi
    done
}

main() {
    install_homebrew
    define_app_lists
    create_brewfile
    install_applications
    setup_asdf
    apply_stow_configs

    # Reload shell configuration if using zsh.
    if [ -f ~/.zshrc ]; then
        log "Sourcing ~/.zshrc..."
        # shellcheck source=/dev/null
        source ~/.zshrc
    fi

    log "Setup complete."
}

main

