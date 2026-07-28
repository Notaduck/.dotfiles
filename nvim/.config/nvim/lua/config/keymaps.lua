vim.g.mapleader = " "

-- Centralized global keymaps table
-- Note: LSP-specific keymaps (gd, gr, K, etc.) are set buffer-locally in core/lsp.lua on_attach
local global_keymaps = {{
    mode = "n",
    lhs = "<leader>cf",
    rhs = vim.lsp.buf.format,
    desc = "Format Buffer"
}, {
    mode = "n",
    lhs = "]d",
    rhs = vim.diagnostic.goto_next,
    desc = "Next Diagnostic"
}, {
    mode = "n",
    lhs = "[d",
    rhs = vim.diagnostic.goto_prev,
    desc = "Prev Diagnostic"
}, {
    mode = "n",
    lhs = "<leader>e",
    rhs = vim.diagnostic.open_float,
    desc = "Show Diagnostic"
}, {
    mode = "n",
    lhs = "<leader>q",
    rhs = vim.diagnostic.setloclist,
    desc = "Diagnostics to Loclist"
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
            l = {"Run Code Lens"},
        },
        e = {"Show Diagnostic"},
        q = {"Diagnostics to Loclist"},
        t = {
            name = "+toggle",
            h = {"Toggle Inlay Hints"},
        },
    }, {
        prefix = "<leader>"
    })
end

