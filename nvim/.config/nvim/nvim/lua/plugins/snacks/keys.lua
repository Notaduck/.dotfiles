-- lua/custom/plugins/snacks/keys.lua
local M = {}

M.keys = {
  -- Top Pickers & Explorer
  {
    '<leader><space>',
    function()
      Snacks.picker.smart()
    end,
    desc = 'Smart Find Files',
  },
  {
    '<leader>,',
    function()
      Snacks.picker.buffers()
    end,
    desc = 'Buffers',
  },
  {
    '<leader>/',
    function()
      Snacks.picker.grep()
    end,
    desc = 'Grep',
  },
  {
    '<leader>:',
    function()
      Snacks.picker.command_history()
    end,
    desc = 'Command History',
  },
  {
    '<leader>n',
    function()
      Snacks.picker.notifications()
    end,
    desc = 'Notification History',
  },
  {
    '<leader>e',
    function()
      Snacks.explorer()
    end,
    desc = 'File Explorer',
  },
  -- find
  {
    '<leader>fb',
    function()
      Snacks.picker.buffers()
    end,
    desc = 'Buffers',
  },
  {
    '<leader>fc',
    function()
      Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
    end,
    desc = 'Find Config File',
  },
  {
    '<leader>ff',
    function()
      vim.notify("FF command triggered", vim.log.levels.INFO)
      Snacks.picker.files {
        find_command = { 'rg', '--files' },
        sorter = function(curr, next, debug)
          -- Enable debug logging
          local debug_enabled = true

          -- Helper function to extract service name from path
          local function get_service_base(file)
            -- Extract the base service name without Interface/Logger/Test suffixes
            local base = file:match("[^/]+$") or file
            return base:gsub("Interface%.ts$", "")
                :gsub("Logger%.ts$", "")
                :gsub("%.test%.ts$", "")
                :gsub("%.spec%.ts$", "")
                :gsub("%.ts$", "")
          end

          -- Helper function to get file priority
          local function get_file_priority(file)
            if file:match("/interfaces/") or file:match("Interface%.ts$") then return 2 end
            if file:match("Logger%.ts$") then return 3 end
            if file:match("%.test%.") or file:match("%.spec%.") then return 4 end
            -- Main implementation files get priority 1
            return 1
          end

          -- Debug logging using the debug parameter
          if debug_enabled and debug then
            debug.log(string.format("Comparing files:\n%s\nvs\n%s", curr, next))
            debug.log(string.format("Base names: %s vs %s", curr_base, next_base))
          end

          -- If they're part of the same service group
          vim.notify(string.format("Base names: %s vs %s", curr_base, next_base), vim.log.levels.INFO)

          -- If they're part of the same service group
          if curr_base == next_base then
            local curr_priority = get_file_priority(curr)
            local next_priority = get_file_priority(next)
            -- Sort by priority within the same service group
            return curr_priority < next_priority
          end

          -- Sort different services alphabetically
          return curr_base < next_base
        end
      }
    end,
    desc = 'Find Files (grouped by service)',
  },
  {
    '<leader>ft',
    function()
      Snacks.picker.files {
        -- Only include test/spec files
        find_command = { 'rg', '--files', '--glob', '**/*.{test,spec}.*' },
        prompt_title = 'Test Files',
      }
    end,
    desc = 'Find Test Files',
  },
  {
    '<leader>fg',
    function()
      Snacks.picker.git_files()
    end,
    desc = 'Find Git Files',
  },
  {
    '<leader>fp',
    function()
      Snacks.picker.projects()
    end,
    desc = 'Projects',
  },
  {
    '<leader>fr',
    function()
      Snacks.picker.recent()
    end,
    desc = 'Recent',
  },
  -- git
  {
    '<leader>gb',
    function()
      Snacks.picker.git_branches()
    end,
    desc = 'Git Branches',
  },
  {
    '<leader>gl',
    function()
      Snacks.picker.git_log()
    end,
    desc = 'Git Log',
  },
  {
    '<leader>gL',
    function()
      Snacks.picker.git_log_line()
    end,
    desc = 'Git Log Line',
  },
  {
    '<leader>gs',
    function()
      Snacks.picker.git_status()
    end,
    desc = 'Git Status',
  },
  {
    '<leader>gS',
    function()
      Snacks.picker.git_stash()
    end,
    desc = 'Git Stash',
  },
  {
    '<leader>gd',
    function()
      Snacks.picker.git_diff()
    end,
    desc = 'Git Diff (Hunks)',
  },
  {
    '<leader>gf',
    function()
      Snacks.picker.git_log_file()
    end,
    desc = 'Git Log File',
  },
  -- Grep
  {
    '<leader>sb',
    function()
      Snacks.picker.lines()
    end,
    desc = 'Buffer Lines',
  },
  {
    '<leader>sB',
    function()
      Snacks.picker.grep_buffers()
    end,
    desc = 'Grep Open Buffers',
  },
  {
    '<leader>sg',
    function()
      Snacks.picker.grep()
    end,
    desc = 'Grep',
  },
  {
    '<leader>sw',
    function()
      Snacks.picker.grep_word()
    end,
    desc = 'Visual selection or word',
    mode = { 'n', 'x' },
  },
  -- search
  {
    '<leader>s"',
    function()
      Snacks.picker.registers()
    end,
    desc = 'Registers',
  },
  {
    '<leader>s/',
    function()
      Snacks.picker.search_history()
    end,
    desc = 'Search History',
  },
  {
    '<leader>sa',
    function()
      Snacks.picker.autocmds()
    end,
    desc = 'Autocmds',
  },
  {
    '<leader>sb',
    function()
      Snacks.picker.lines()
    end,
    desc = 'Buffer Lines',
  },
  {
    '<leader>sc',
    function()
      Snacks.picker.command_history()
    end,
    desc = 'Command History',
  },
  {
    '<leader>sC',
    function()
      Snacks.picker.commands()
    end,
    desc = 'Commands',
  },
  {
    '<leader>sd',
    function()
      Snacks.picker.diagnostics()
    end,
    desc = 'Diagnostics',
  },
  {
    '<leader>sD',
    function()
      Snacks.picker.diagnostics_buffer()
    end,
    desc = 'Buffer Diagnostics',
  },
  {
    '<leader>sh',
    function()
      Snacks.picker.help()
    end,
    desc = 'Help Pages',
  },
  {
    '<leader>sH',
    function()
      Snacks.picker.highlights()
    end,
    desc = 'Highlights',
  },
  {
    '<leader>si',
    function()
      Snacks.picker.icons()
    end,
    desc = 'Icons',
  },
  {
    '<leader>sj',
    function()
      Snacks.picker.jumps()
    end,
    desc = 'Jumps',
  },
  {
    '<leader>sk',
    function()
      Snacks.picker.keymaps()
    end,
    desc = 'Keymaps',
  },
  {
    '<leader>sl',
    function()
      Snacks.picker.loclist()
    end,
    desc = 'Location List',
  },
  {
    '<leader>sm',
    function()
      Snacks.picker.marks()
    end,
    desc = 'Marks',
  },
  {
    '<leader>sM',
    function()
      Snacks.picker.man()
    end,
    desc = 'Man Pages',
  },
  {
    '<leader>sp',
    function()
      Snacks.picker.lazy()
    end,
    desc = 'Search for Plugin Spec',
  },
  {
    '<leader>sq',
    function()
      Snacks.picker.qflist()
    end,
    desc = 'Quickfix List',
  },
  {
    '<leader>sR',
    function()
      Snacks.picker.resume()
    end,
    desc = 'Resume',
  },
  {
    '<leader>su',
    function()
      Snacks.picker.undo()
    end,
    desc = 'Undo History',
  },
  {
    '<leader>uC',
    function()
      Snacks.picker.colorschemes()
    end,
    desc = 'Colorschemes',
  },
  -- LSP
  {
    'gd',
    function()
      Snacks.picker.lsp_definitions()
    end,
    desc = 'Goto Definition',
  },
  {
    'gD',
    function()
      Snacks.picker.lsp_declarations()
    end,
    desc = 'Goto Declaration',
  },
  {
    'gr',
    function()
      Snacks.picker.lsp_references()
    end,
    nowait = true,
    desc = 'References',
  },
  {
    'gI',
    function()
      Snacks.picker.lsp_implementations()
    end,
    desc = 'Goto Implementation',
  },
  {
    'gy',
    function()
      Snacks.picker.lsp_type_definitions()
    end,
    desc = 'Goto T[y]pe Definition',
  },
  {
    '<leader>ss',
    function()
      Snacks.picker.lsp_symbols()
    end,
    desc = 'LSP Symbols',
  },
  {
    '<leader>sS',
    function()
      Snacks.picker.lsp_workspace_symbols()
    end,
    desc = 'LSP Workspace Symbols',
  },
  {
    '<leader>z',
    function()
      Snacks.zen()
    end,
    desc = 'Toggle Zen Mode',
  },
  {
    '<leader>Z',
    function()
      Snacks.zen.zoom()
    end,
    desc = 'Toggle Zoom',
  },
  {
    '<leader>.',
    function()
      Snacks.scratch()
    end,
    desc = 'Toggle Scratch Buffer',
  },
  {
    '<leader>S',
    function()
      Snacks.scratch.select()
    end,
    desc = 'Select Scratch Buffer',
  },
  {
    '<leader>n',
    function()
      Snacks.notifier.show_history()
    end,
    desc = 'Notification History',
  },
  {
    '<leader>bd',
    function()
      Snacks.bufdelete()
    end,
    desc = 'Delete Buffer',
  },
  {
    '<leader>cR',
    function()
      Snacks.rename.rename_file()
    end,
    desc = 'Rename File',
  },
  {
    '<leader>gB',
    function()
      Snacks.gitbrowse()
    end,
    desc = 'Git Browse',
    mode = { 'n', 'v' },
  },
  {
    '<leader>gb',
    function()
      Snacks.git.blame_line()
    end,
    desc = 'Git Blame Line',
  },
  {
    '<leader>gf',
    function()
      Snacks.lazygit.log_file()
    end,
    desc = 'Lazygit Current File History',
  },
  {
    '<leader>gg',
    function()
      Snacks.lazygit()
    end,
    desc = 'Lazygit',
  },
  {
    '<leader>gl',
    function()
      Snacks.lazygit.log()
    end,
    desc = 'Lazygit Log (cwd)',
  },
  {
    '<leader>un',
    function()
      Snacks.notifier.hide()
    end,
    desc = 'Dismiss All Notifications',
  },
  {
    '<c-/>',
    function()
      Snacks.terminal()
    end,
    desc = 'Toggle Terminal',
  },
  {
    '<c-_>',
    function()
      Snacks.terminal()
    end,
    desc = 'which_key_ignore',
  },
  {
    ']]',
    function()
      Snacks.words.jump(vim.v.count1)
    end,
    desc = 'Next Reference',
    mode = { 'n', 't' },
  },
  {
    '[[',
    function()
      Snacks.words.jump(-vim.v.count1)
    end,
    desc = 'Prev Reference',
    mode = { 'n', 't' },
  },
  {
    '<leader>N',
    desc = 'Neovim News',
    function()
      Snacks.win {
        file = vim.api.nvim_get_runtime_file('doc/news.txt', false)[1],
        width = 0.6,
        height = 0.6,
        wo = {
          spell = false,
          wrap = false,
          signcolumn = 'yes',
          statuscolumn = ' ',
          conceallevel = 3,
        },
      }
    end,
  },
  {
    '<leader>sn',
    function()
      local config_path = vim.fn.stdpath 'config'
      Snacks.picker.files {
        cwd = config_path,
        prompt_title = 'Lua Files',
        find_command = { 'rg', '--files', '--iglob', '*.lua' },
      }
    end,
    desc = 'Find Lua Files in nvim config',
  },
}

M.init = function()
  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    callback = function()
      -- Setup some globals for debugging (lazy-loaded)
      -- Use _G.Snacks to avoid undefined global warnings
      _G.dd = function(...)
        _G.Snacks.debug.inspect(...)
      end
      _G.bt = function()
        _G.Snacks.debug.backtrace()
      end
      vim.print = _G.dd -- Override print to use snacks for `:=` command

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
      Snacks.toggle
          .option('background', {
            off = 'light',
            on = 'dark',
            name = 'Dark Background',
          })
          :map '<leader>ub'
      Snacks.toggle.inlay_hints():map '<leader>uh'
      Snacks.toggle.indent():map '<leader>ug'
      Snacks.toggle.dim():map '<leader>uD'
    end,
  })
end

return M
