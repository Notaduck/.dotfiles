vim.g.mapleader = " "

-- Centralized global keymaps table
local global_keymaps = {{
    mode = "n",
    lhs = "<leader>ca",
    rhs = vim.lsp.buf.code_action,
    desc = "Code Action"
}, {
    mode = "n",
    lhs = "<leader>cr",
    rhs = vim.lsp.buf.rename,
    desc = "Rename Symbol"
}, {
    mode = "n",
    lhs = "<leader>cf",
    rhs = vim.lsp.buf.format,
    desc = "Format Buffer"
}, {
    mode = "n",
    lhs = "<leader>cd",
    rhs = vim.lsp.buf.definition,
    desc = "Goto Definition"
}}

for _, map in ipairs(global_keymaps) do
    local ok, err = pcall(vim.keymap.set, map.mode, map.lhs, map.rhs, {
        desc = map.desc
    })
    if not ok then
        vim.notify("Failed to set keymap: " .. map.lhs .. "\n" .. tostring(err), vim.log.levels.WARN)
    end
end

-- which-key integration (optional, if installed)
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
    wk.register({
        c = {
            name = "+code",
            a = {"Code Action"},
            r = {"Rename Symbol"},
            f = {"Format Buffer"},
            d = {"Goto Definition"}
        }
    }, {
        prefix = "<leader>"
    })
end

