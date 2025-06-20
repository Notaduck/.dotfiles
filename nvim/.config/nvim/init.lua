--[[
Neovim config entrypoint

Structure:
- config/options.lua: General options
- config/keymaps.lua: All global keymaps (as a table, registered in a loop)
- config/autocmds.lua: Autocommands
- core/lazy.lua: Plugin manager (lazy.nvim) setup, all plugin specs go here
- core/lsp.lua: LSP setup and helpers
- All plugin setup is deferred/lazy-loaded via lazy.nvim, not in init.lua

Startup is robust: all requires are wrapped in safe_require, and important events use vim.notify.
]] local function safe_require(mod)
    local ok, err = pcall(require, mod)
    if not ok then
        vim.notify("Failed to load module: " .. mod .. "\n" .. tostring(err), vim.log.levels.WARN)
    end
end

if vim.loader and vim.loader.enable then
    vim.loader.enable()
end

safe_require("config.options")
safe_require("config.keymaps")
safe_require("config.autocmds")
safe_require("core.lazy")
safe_require("core.lsp")
