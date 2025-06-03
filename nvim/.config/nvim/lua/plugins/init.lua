-- This file returns a table of all plugin specs
return {
  -- Core plugins from kickstart
  -- { import = 'kickstart.plugins.debug' },
  { import = 'kickstart.plugins.gitsigns' },
  -- { import = 'kickstart.plugins.indent_line' },
  { import = 'kickstart.plugins.lint' },

  -- LSP, Completion & Debugging
  { import = 'plugins.lsp' },
  { import = 'plugins.completion' }, -- Use local completion config
  -- { import = 'plugins.debug' },
  -- { import = 'plugins.npm_debug' },
  { import = 'plugins.inlay-hints' },

  -- UI Components
  { import = 'plugins.lualine' },
  { import = 'plugins.trouble' },
  { import = 'plugins.no-neck-pain' },
  { import = 'plugins.tiny-inline-diagnostics' },

  -- Editor Enhancements
  -- { import = 'plugins.autopairs' },
  { import = 'plugins.multi-cursor' },
  { import = 'plugins.surround' },
  { import = 'plugins.indent' },

  -- Development Tools
  { import = 'plugins.typed-rocks' },
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
  },

  -- AI & Copilot
  { import = 'plugins.avante' },

  -- Themes & UI
  -- { import = 'plugins.rose-pine' },
  { import = 'plugins.catppuccin' },
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
  },

  -- Additional Utilities
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {},
  },
  {
    'echasnovski/mini.nvim',
    version = false,
    config = function()
      require('mini.basics').setup()
      require('mini.ai').setup()
      require('mini.pairs').setup()
    end,
  },
  'tpope/vim-sleuth',
}
