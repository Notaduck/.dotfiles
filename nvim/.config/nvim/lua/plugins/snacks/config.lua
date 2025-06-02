---@type snacks.Config
local opts = {
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      { section = "header" },
      {
        pane = 2,
        section = "terminal",
        cmd = "colorscript -e square",
        height = 5,
        padding = 1,
      },
      { section = "keys", gap = 1, padding = 1 },
      { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
      { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
      {
        pane = 2,
        icon = " ",
        title = "Git Status",
        section = "terminal",
        enabled = function()
          return Snacks.git.get_root() ~= nil
        end,
        cmd = "git status --short --branch --renames",
        height = 5,
        padding = 1,
        ttl = 5 * 60,
        indent = 3,
      },
      { section = "startup" },
    },
  },
  explorer = {
    enabled = true,
    position = 'right',
    pos = 'right',
    width = 40,
    layout = { position = 'right' },
  },
  indent = {
    enabled = true,
    animate = {
      enabled = false
    },
  },
  input = { enabled = true },
  notifier = {
    enabled = true,
    timeout = 3000,
  },
  picker = {
    enabled = true,
    sources = {
      explorer = {
        finder = 'explorer',
        sort = { fields = { 'sort' } },
        supports_live = true,
        tree = true,
        watch = true,
        diagnostics = true,
        diagnostics_open = false,
        git_status = true,
        git_status_open = false,
        git_untracked = true,
        grep = {
          exclude = {
            "node_modules/**",
            "package-lock.json",
            "yarn.lock",
            "pnpm-lock.yaml",
            "dist/**",
            "build/**",
            ".git/**",
            "*.min.js",
            "*.min.css"
          },
        },
        hidden = true,
        follow_file = true,
        focus = 'list',
        auto_close = false,
        jump = { close = false },
        layout = { layout = { position = 'right' } },
        formatters = {
          file = { filename_only = true },
          severity = { pos = 'right' },
        },
        matcher = { sort_empty = false, fuzzy = false },
        config = function(explorer_opts)
          return require('snacks.picker.source.explorer').setup(explorer_opts)
        end,
        win = {
          list = {
            keys = {
              ['<BS>'] = 'explorer_up',
              ['l'] = 'confirm',
              ['h'] = 'explorer_close',
              ['a'] = 'explorer_add',
              ['d'] = 'explorer_del',
              ['r'] = 'explorer_rename',
              ['c'] = 'explorer_copy',
              ['m'] = 'explorer_move',
              ['o'] = 'explorer_open',
              ['P'] = 'toggle_preview',
              ['y'] = 'explorer_yank',
              ['u'] = 'explorer_update',
              ['<c-c>'] = 'tcd',
              ['<leader>/'] = 'picker_grep',
              ['<c-t>'] = 'terminal',
              ['.'] = 'explorer_focus',
              ['I'] = 'toggle_ignored',
              ['H'] = 'toggle_hidden',
              ['Z'] = 'explorer_close_all',
              [']g'] = 'explorer_git_next',
              ['[g'] = 'explorer_git_prev',
              [']d'] = 'explorer_diagnostic_next',
              ['[d'] = 'explorer_diagnostic_prev',
              [']w'] = 'explorer_warn_next',
              ['[w'] = 'explorer_warn_prev',
              [']e'] = 'explorer_error_next',
              ['[e'] = 'explorer_error_prev',
            },
          },
        },
      },
    },
  },
  quickfile = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = true },
  words = { enabled = true },
  styles = {
    notification = {
      -- e.g., wrap text if needed:
      -- wo = { wrap = true },
    },
  },
  ---@class snacks.picker.debug
  debug = {
    scores = true,    -- show scores in the list
    leaks = false,    -- show when pickers don't get garbage collected
    explorer = false, -- show explorer debug info
    files = true,     -- show file debug info
    grep = false,     -- show file debug info
    proc = false,     -- show proc debug info
    extmarks = false, -- show extmarks errors
  },
}

return { opts = opts }
