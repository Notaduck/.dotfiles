-- Disable netrw (using snacks explorer instead)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.undofile = true
vim.opt.confirm = true
vim.opt.updatetime = 300

-- Deferred: resolving the clipboard provider on macOS adds startup time
vim.schedule(function()
	vim.opt.clipboard = "unnamedplus"
end)
