return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add = { text = "┃" },
      change = { text = "┃" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    signs_staged = {
      add = { text = "┃" },
      change = { text = "┃" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    signs_staged_enable = true,
    signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
    numhl = false,   -- Toggle with `:Gitsigns toggle_numhl`
    linehl = false,  -- Toggle with `:Gitsigns toggle_linehl`
    word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
    watch_gitdir = {
      follow_files = true,
    },
    auto_attach = true,
    attach_to_untracked = false,
    current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
      delay = 1000,
      ignore_whitespace = false,
      virt_text_priority = 100,
      use_focus = true,
    },
    current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil, -- Use default
    max_file_length = 40000, -- Disable if file is longer than this (in lines)
    preview_config = {
      -- Options passed to nvim_open_win
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
  },
}

-- local gs = require("gitsigns")
--
-- gs.setup {
--   signs = {
--     add = { text = "+" },
--     change = { text = "~" },
--     delete = { text = "_" },
--     topdelete = { text = "‾" },
--     changedelete = { text = "│" },
--   },
--   word_diff = false,
--   on_attach = function(bufnr)
--     local function map(mode, l, r, opts)
--       opts = opts or {}
--       opts.buffer = bufnr
--       vim.keymap.set(mode, l, r, opts)
--     end
--
--     -- Navigation
--     map("n", "]c", function()
--       if vim.wo.diff then
--         return "]c"
--       end
--       vim.schedule(function()
--         gs.next_hunk()
--       end)
--       return "<Ignore>"
--     end, { expr = true, desc = "next hunk" })
--
--     map("n", "[c", function()
--       if vim.wo.diff then
--         return "[c"
--       end
--       vim.schedule(function()
--         gs.prev_hunk()
--       end)
--       return "<Ignore>"
--     end, { expr = true, desc = "previous hunk" })
--
--     -- Actions
--     map("n", "<leader>hp", gs.preview_hunk, { desc = "preview hunk" })
--     map("n", "<leader>hb", function()
--       gs.blame_line { full = true }
--     end, { desc = "blame hunk" })
--   end,
-- }
--
-- vim.api.nvim_create_autocmd("ColorScheme", {
--   pattern = "*",
--   callback = function()
--     vim.cmd([[
--       hi GitSignsChangeInline gui=reverse
--       hi GitSignsAddInline gui=reverse
--       hi GitSignsDeleteInline gui=reverse
--     ]])
--   end,
-- })
