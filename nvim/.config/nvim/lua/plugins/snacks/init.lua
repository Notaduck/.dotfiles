-- lua/custom/plugins/snacks/init.lua
local config = require 'plugins.snacks.config'
local keys = require 'plugins.snacks.keys'
-- local autocmds = require 'plugins.snacks.autocmds'
-- Load our npm scripts module
local npm_scripts = require 'plugins.snacks.npm_scripts'

-- Set up any autocommands you need on startup
-- autocmds.setup()

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = config.opts,
  keys = keys.keys,
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print for the `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
        Snacks.toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>uL'
        Snacks.toggle.diagnostics():map '<leader>ud'
        Snacks.toggle.line_number():map '<leader>ul'
        Snacks.toggle
            .option('conceallevel', {
              off = 0,
              on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
            })
            :map '<leader>uc'
        Snacks.toggle.treesitter():map '<leader>uT'
        Snacks.toggle.option('background', {
          off = 'light',
          on = 'dark',
          name = 'Dark Background',
        })
        Snacks.toggle.indent():map '<leader>ug'
        Snacks.toggle.dim():map '<leader>uD'

        -- Register npm script commands to make them available via command line
        vim.api.nvim_create_user_command('NpmRun', function()
          require('plugins.snacks.npm_scripts').run_npm_script()
        end, {
          desc = 'Run npm script from package.json',
        })

        vim.api.nvim_create_user_command('YarnRun', function()
          require('plugins.snacks.npm_scripts').run_yarn_script()
        end, {
          desc = 'Run yarn script from package.json',
        })
        Snacks.toggle.indent():map '<leader>ug'
        Snacks.toggle.dim():map '<leader>uD'
      end,
    })
    vim.api.nvim_create_user_command("SearchFolder", function()
      Snacks.grep.dir()
    end, {})
  end,
}
