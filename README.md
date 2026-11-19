# dotfiles

macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package that mirrors `$HOME`, so
`zsh/.zshrc` becomes `~/.zshrc` and `nvim/.config/nvim` becomes `~/.config/nvim`.

## Packages

| Package | Installs | Notes |
|---|---|---|
| `zsh` | `~/.zshrc` | zinit plugins, pure prompt, asdf shims, direnv, zoxide, loads `~/.env` |
| `nvim` | `~/.config/nvim` | lazy.nvim, native LSP configs in `lua/lsp/`, blink completion, snacks |
| `tmux` | `~/.tmux.conf` | `prefix s` opens the sesh session picker; resurrect + continuum |
| `ghostty` | `~/.config/ghostty` | JetBrainsMono Nerd Font, rose-pine themes |
| `asdf` | `~/.tool-versions`, `~/.default-npm-packages` | global runtime versions |
| `bat` | `~/.config/bat/themes` | Catppuccin themes (run `bat cache --build` after stowing) |
| `btop` | `~/.config/btop/btop.conf` | |
| `wallpapers` | `~/.wallpapers` | |

Other files in the repo root:

- `Brewfile`: every Homebrew formula, cask and font the setup needs.
- `setup_mac.sh`: bootstraps a new Mac (see below).
- `.stowrc`: sets the stow target to `~` and ignores `.DS_Store`, so
  `stow <pkg>` works from the repo root without extra flags.

## New machine

```sh
git clone https://github.com/Notaduck/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup_mac.sh
```

The script:

1. installs or updates Homebrew,
2. runs `brew bundle` against the `Brewfile`,
3. stows every package listed in `STOW_PACKAGES`,
4. adds the asdf plugins named in `~/.tool-versions` and installs those versions.

Stow refuses to overwrite real files. If the machine already has a `~/.zshrc`
or similar, move it aside (or merge it into the package) and re-run the script.

## Day to day

```sh
stow nvim        # link a package
stow -R nvim     # relink after adding or removing files in it
stow -D nvim     # unlink
```

Edit configs in place: `~/.zshrc` and the other targets are symlinks into this
repo, so every change shows up in `git status` here.

### Adding a package

1. Create `<name>/` mirroring the path under `$HOME`, e.g.
   `lazygit/.config/lazygit/config.yml`.
2. Move the existing config into it and run `stow <name>`.
3. Add `<name>` to `STOW_PACKAGES` in `setup_mac.sh` and to the table above.
4. If it needs software, add it to the `Brewfile`.

### Checking for drift

Apps sometimes replace a symlink with a real file when they save (Karabiner is
the classic offender). A dry run reports any target that is no longer a link:

```sh
cd ~/.dotfiles && for p in */; do stow -n -R "${p%/}"; done 2>&1 | grep -v 'simulation mode'
```

No output means everything is linked. For a conflict, diff the real file
against the repo copy, merge, delete the real file and run `stow -R <pkg>`.

## Secrets

Nothing secret belongs in this repo. Machine-specific or sensitive values go in
`~/.env` (sourced by `.zshrc`) or `~/.zshenv`, neither of which is tracked.
