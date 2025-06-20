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
        -- Skip showing diagnostics if we just saved the file
        local now = vim.loop.now()
        local last_save = vim._last_save_time or 0
        if (now - last_save) < 500 then -- 500ms delay after save
            return
        end

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
                border = "rounded",
                source = "if_many",
                prefix = " ",
                scope = "line" -- Changed from 'cursor' to 'line'
            }
            vim.diagnostic.open_float(nil, opts)
        end
    end
})

-- Track the last save time
vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
        vim._last_save_time = vim.loop.now()
    end
})

-- Reduce the time before showing diagnostics (default is 4000ms)
vim.opt.updatetime = 300

-- Helper: Get active LSP client names for statusline
local function lsp_client_names()
    local clients = vim.lsp.get_clients({
        bufnr = 0
    })
    if #clients == 0 then
        return ""
    end
    local names = {}
    for _, client in ipairs(clients) do
        table.insert(names, client.name)
    end
    return table.concat(names, ", ")
end

-- Diagnostic config (already good!)
vim.diagnostic.config({
    virtual_text = {
        prefix = "●",
        spacing = 4,
        source = "if_many",
        severity = {
            min = vim.diagnostic.severity.WARN
        }
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚",
            [vim.diagnostic.severity.WARN] = "󰀪",
            [vim.diagnostic.severity.INFO] = "󰋽",
            [vim.diagnostic.severity.HINT] = "󰌶"
        },
        linehl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError"
        },
        numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn"
        }
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "rounded",
        source = "if_many",
        header = "",
        prefix = "",
        focusable = false
    }
})

-- Attach LSP clients to new buffers
-- local function try_attach_lsp(args)
--     local bufnr = args.buf
--     local clients = vim.lsp.get_clients()
--     local filepath = vim.api.nvim_buf_get_name(bufnr)
--     local ft = vim.bo[bufnr].filetype

--     if filepath == "" or filepath:match("^%a+://") then
--         return
--     end

--     for _, client in ipairs(clients) do
--         local should_attach = false
--         if client.config and client.config.filetypes then
--             for _, supported_ft in ipairs(client.config.filetypes) do
--                 if supported_ft == ft then
--                     should_attach = true
--                     break
--                 end
--             end
--         end
--         if not should_attach then
--             if (ft == "typescript" or ft == "javascript" or ft == "typescriptreact" or ft == "javascriptreact") and
--                 (client.name == "vtsls" or client.name == "tsserver") or (ft == "lua" and client.name == "lua_ls") or
--                 (ft == "python" and client.name == "pyright") or
--                 ((ft == "yaml" or ft == "yml") and client.name == "yamlls") or (ft == "go" and client.name == "gopls") or
--                 ((ft == "json" or ft == "jsonc") and client.name == "jsonls") or
--                 (ft == "dockerfile" and client.name == "dockerls") then
--                 should_attach = true
--             end
--         end
--         if should_attach and not vim.lsp.buf_is_attached(bufnr, client.id) then
--             vim.lsp.buf_attach_client(bufnr, client.id)
--             -- Optionally: vim.notify("Attached " .. client.name .. " to buffer " .. bufnr, vim.log.levels.DEBUG)
--         end
--     end
-- end

-- vim.api.nvim_create_autocmd({"BufReadPost", "BufNewFile"}, {
--     callback = try_attach_lsp
-- })

-- BufWritePre: Format and organize imports
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = {"*.ts", "*.tsx", "*.js", "*.jsx", "*.lua", "*.py", "*.go"},
    callback = function()
        vim.lsp.buf.format({
            async = false,
            timeout_ms = 5000
        })
        local clients = vim.lsp.get_clients({
            bufnr = 0
        })
        local position_encoding = clients[1] and clients[1].offset_encoding or "utf-16"
        local params = vim.lsp.util.make_range_params(nil, position_encoding)
        params.context = {
            only = {"source.organizeImports"}
        }
        local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
        if result then
            for _, res in pairs(result) do
                for _, r in pairs(res.result or {}) do
                    if r.edit then
                        vim.lsp.util.apply_workspace_edit(r.edit, position_encoding)
                    elseif r.command then
                        vim.lsp.buf.execute_command(r.command)
                    end
                end
            end
        end
    end
})

-- LSP progress handler (let fidget.nvim handle UI)
vim.lsp.handlers["$/progress"] = nil
