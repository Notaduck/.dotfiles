vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Centralized global keymaps table
-- Note: LSP-specific keymaps are set buffer-locally in core/lsp.lua on_attach.
-- ]d / [d and gr* are Neovim defaults; formatting lives in plugins/conform.lua;
-- which-key groups live in plugins/whichkey.lua.
local global_keymaps = {{
    mode = "n",
    lhs = "<leader>cd",
    rhs = vim.diagnostic.open_float,
    desc = "Line Diagnostics"
}}

for _, map in ipairs(global_keymaps) do
    local ok, err = pcall(vim.keymap.set, map.mode, map.lhs, map.rhs, {
        desc = map.desc
    })
    if not ok then
        vim.notify("Failed to set keymap: " .. map.lhs .. "\n" .. tostring(err), vim.log.levels.WARN)
    end
end
