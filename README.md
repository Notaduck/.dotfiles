# dotfiles

macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package that mirrors `$HOME`, so
`zsh/.zshrc` becomes `~/.zshrc` and `nvim/.config/nvim` becomes `~/.config/nvim`.

## Packages

| Package | Installs | Notes |
|---|---|---|
| `zsh` | `~/.zshrc`, `~/.zprofile` | vi keys, pure prompt, autosuggestions and fast-syntax-highlighting (all three from Homebrew), fzf, direnv, zoxide as `cd`, `rm` moves to the Trash; `.zprofile` runs `brew shellenv` and builds `PATH` (asdf shims first) |
| `nvim` | `~/.config/nvim` | lazy.nvim, native LSP configs in `lua/lsp/`, blink completion, snacks |
| `tmux` | `~/.tmux.conf` | prefix `Ctrl+B` shows a key hint in the status line; `prefix s` opens the sesh session picker; resurrect + continuum |
| `ghostty` | `~/.config/ghostty` | JetBrainsMono Nerd Font; `themes/rose-pine.conf` backs the `rose-pine` palette, every other theme is built into Ghostty |
| `theme` | `~/.local/bin/theme`, `~/.config/theme/palettes` | one command to switch the colour scheme everywhere (see below) |
| `asdf` | `~/.tool-versions`, `~/.default-npm-packages` | global runtime versions |
| `bat` | `~/.config/bat/themes` | Catppuccin themes (run `bat cache --build` after stowing) |
| `btop` | `~/.config/btop/btop.conf` | |
| `tern` | `~/Library/Application Support/Tern/{plugins/*,themes/*}`, `~/.local/bin/tern-plugin-audit` | Tern plugins (`gh-actions`, `jira-sprint`, `nvim-open`, `omp-projects`, `pane-keys`, `sidebar-session`, `tiling`) and notebook-paper themes. `sidebar-session` is CSS only: in the Tiles layout with vertical tabs it moves the avatar and session switcher from the titlebar to the top of the sidebar and hides the titlebar's + button. Plugin data stays local: `jira-sprint` reads site, email and repos from `plugin-data/jira-sprint/jira.json` (written with placeholders on first run), `omp-projects` its list from `plugin-data/omp-projects/projects.json`. [Overseer](https://github.com/mmnavarr/overseer) is installed separately (`tern plugin install github.com/mmnavarr/overseer`, needs `worktrunk`) and patched by hand so ticket links open Jira: `ticketFor` in its `window.luau` builds `https://<site>.atlassian.net/browse/<KEY>`, plus "Linear" → "Jira" in `view.luau` and `visualize.luau`. Updating Overseer drops the patch |
| `omp` | `~/.omp/agent/{config.yml,models.yml,mcp.json,APPEND_SYSTEM.md,extensions/*,themes/*}`, `~/.local/bin/{omp-sessions,ideas}` | omp settings, local Ollama models, Atlassian and Notion MCP, notebook themes. Extensions: `session-title`, `implement` (`/implement <KEY>` plans a Jira issue), `ideas`, `plan-panel`, `scheduled-prompt`, and `query-cache` (stores read-only AWS CLI results and MCP results of tools the server marks read-only in `~/.cache/omp/query-cache.sqlite` for 30 days; the agent searches it with the `query_cache` tool, it never answers a query on its own). `omp-sessions` finds and resumes sessions; `ideas` is the ideas-store CLI for GUI apps. Skills are not tracked |

Other files in the repo root:

- `tern-settings.json`: Tern's `settings.json`. Tern saves it by replacing the
  file, which breaks a stow link, so `setup_mac.sh` copies it into place once.
  Copy changes back with
  `cp ~/Library/Application\ Support/Tern/settings.json ~/.dotfiles/tern-settings.json`.
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
2. runs `brew bundle` against the `Brewfile` (omp comes from the `can1357/tap` tap),
3. stows every package listed in `STOW_PACKAGES`,
4. copies `tern-settings.json` into place if Tern has no settings yet,
5. enables Touch ID for `sudo` (asks for your password once),
6. turns off macOS press-and-hold in Tern so held keys repeat,
7. applies the default colour scheme with `theme catppuccin-mocha`,
8. adds the asdf plugins named in `~/.tool-versions` and installs those versions.

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

### Colour scheme

`theme` opens an fzf picker: move through the list, see each palette rendered
on the right, press enter to apply it everywhere (Ghostty, Neovim, bat, omp
and Tern) and reload whatever is running. tmux is not switched: it always uses
Catppuccin Mocha. The default everywhere is `catppuccin-mocha`. The other forms:

```sh
theme catppuccin-mocha   # switch without the picker
theme list               # all known themes
theme current            # the active one
theme toggle             # next in the list
theme preview nord       # what the picker shows for one theme
```

Shipped themes: Catppuccin (latte, frappe, macchiato, mocha), Rose Pine
(main, moon, dawn), Tokyo Night (night, storm, moon, day), Kanagawa (wave,
dragon, lotus), Gruvbox (dark, light), Everforest (dark, light), Nord and
Dracula.

Each theme is one palette file in `theme/.config/theme/palettes/<name>.conf`,
in tmux syntax so tmux can source it directly. It holds the colours as
`@thm_*` roles plus the per-app names (`@thm_nvim`, `@thm_ghostty`,
`@thm_bat`, `@thm_omp`, `@thm_mode`). The active choice goes to
`~/.local/state/theme/` (not tracked): Ghostty includes `ghostty` from there,
Neovim reads `current` in `lua/config/theme.lua`, and `.zshrc` exports
`BAT_THEME` from `bat`. `~/.tmux.conf` sources `catppuccin-mocha.conf` directly.
Reloading Ghostty clicks its "Reload Configuration" menu item, which needs
Accessibility access for the terminal; without it, press `cmd+shift+,`.

omp gets the `@thm_omp` name in both `theme.dark` and `theme.light` through
`omp config set`, so `omp/.omp/agent/config.yml` (tracked) changes when you
switch away from the default. Tern follows omp's theme as long as
`theme_dark`/`theme_light` are absent from Tern's `settings.json`; setting a
theme in Tern's own settings pins it again. omp has no Kanagawa or Rose Pine
Dawn theme, so those map to the nearest built-in (`dark-tokyo-night`,
`dark-gruvbox`, `light-gruvbox`, `light-opal`).

Adding a theme:

1. Copy a palette file and fill in the colours. Pick the Ghostty name from
   `ghostty +list-themes` (or drop a file in `ghostty/.config/ghostty/themes/`),
   the bat name from `bat --list-themes` (`ansi` follows the terminal colours),
   the omp/Tern name from omp's `/settings` → Appearance (Tern lists the same
   names), e.g. `dark-catppuccin`.
2. If the Neovim colorscheme is a new plugin, add a spec in
   `nvim/.config/nvim/lua/colorschemes/`.

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

Nothing secret belongs in this repo. Secrets live in the login Keychain and are
read on demand with `secret NAME` (defined in `.zshrc`), so they are not
exported to every process. Add or replace one with
`security add-generic-password -U -a "$USER" -s NAME -w`, which prompts for the
value. Other machine-specific values go in `~/.zshenv`, which is not tracked.
