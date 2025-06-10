vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.clipboard = "unnamedplus"

-- Set colorscheme with a VimEnter event to ensure it happens after plugins load
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        vim.cmd.colorscheme("catppuccin-latte")
    end,
    once = true
})
