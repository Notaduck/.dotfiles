-- Set colorscheme with a VimEnter event to ensure it happens after plugins load
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
  once = true,
})
