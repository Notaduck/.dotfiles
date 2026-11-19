local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({"git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
                   lazypath})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({{
    import = "plugins"
}, {
    import = "colorschemes"
}}, {
    lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
    rocks = { hererocks = false },
})

-- Colorscheme plugins load eagerly above; pick the one the `theme` command
-- selected (see config/theme.lua).
require("config.theme").apply()
