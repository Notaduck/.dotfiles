-- Create highlight group for active parameter
vim.cmd([[
  highlight Parameter guifg=#88CCFF gui=bold
]])

local lsp_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../lsp"
for _, file in ipairs(vim.fn.readdir(lsp_dir)) do
    if file:match("%.lua$") then
        require("lsp." .. file:gsub("%.lua$", ""))
    end
end

-- Show diagnostic popup on cursor hold (anywhere on the line)
vim.api.nvim_create_autocmd({"CursorHold"}, {
    callback = function()
        -- Get current line number (0-indexed)
        local line = vim.api.nvim_win_get_cursor(0)[1] - 1

        -- Get all diagnostics for the current line
        local diagnostics = vim.diagnostic.get(0, {
            lnum = line
        })

        -- Only show float if there are diagnostics on this line
        if #diagnostics > 0 then
            local opts = {
                focusable = false,
                close_events = {"BufLeave", "CursorMoved", "InsertEnter", "FocusLost"},
                border = 'rounded',
                source = 'if_many',
                prefix = ' ',
                scope = 'line' -- Changed from 'cursor' to 'line'
            }
            vim.diagnostic.open_float(nil, opts)
        end
    end
})

-- Reduce the time before showing diagnostics (default is 4000ms)
vim.opt.updatetime = 300

vim.diagnostic.config({
    virtual_text = {
        prefix = '●',
        spacing = 4,
        source = 'if_many',
        severity = {
            min = vim.diagnostic.severity.WARN
        } -- Only show warnings and errors in virtual text
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚",
            [vim.diagnostic.severity.WARN] = "󰀪",
            [vim.diagnostic.severity.INFO] = "󰋽",
            [vim.diagnostic.severity.HINT] = "󰌶"

        },
        -- You can also set custom highlight groups
        linehl = {
            [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError'
        },
        numhl = {
            [vim.diagnostic.severity.ERROR] = 'DiagnosticSignError',
            [vim.diagnostic.severity.WARN] = 'DiagnosticSignWarn'
        }
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = 'rounded',
        source = 'if_many',
        header = '',
        prefix = '',
        focusable = false
    }
})

-- Enhanced BufWritePre autocommand for formatting and removing unused imports
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {"*.ts", "*.tsx", "*.js", "*.jsx", "*.lua", "*.py", "*.go"},
    callback = function()
        -- Format document first
        vim.lsp.buf.format({
            async = false,
            timeout_ms = 5000
        })

        -- Organize imports (handles removing unused imports in most LSPs)
        local params = vim.lsp.util.make_range_params()
        params.context = {
            only = {"source.organizeImports"}
        }
        local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
        for _, res in pairs(result or {}) do
            for _, r in pairs(res.result or {}) do
                if r.edit then
                    vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
                elseif r.command then
                    vim.lsp.buf.execute_command(r.command)
                end
            end
        end
    end
})
