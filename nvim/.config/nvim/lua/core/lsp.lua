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

-- LSP progress handler (let fidget.nvim handle UI)
vim.lsp.handlers["$/progress"] = nil

local M = {}

function M.on_attach(client, bufnr)
    if client.supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, {
            bufnr = bufnr
        })
    end
    vim.keymap.set('n', '<leader>th', function()
        local current = vim.lsp.inlay_hint.is_enabled({
            bufnr = bufnr
        })
        vim.lsp.inlay_hint.enable(not current, {
            bufnr = bufnr
        })
        vim.notify("🔄 Inlay hints " .. (current and "disabled" or "enabled"))
    end, {
        buffer = bufnr,
        desc = '[T]oggle Inlay [H]ints'
    })
end

function M.setup_lsp(opts)
    opts = vim.tbl_deep_extend("force", {
        single_file_support = true,
        autostart = true,
        reuse_client = function(client, config)
            return client.name == config.name and client.config.root_dir == config.root_dir
        end,
        on_attach = M.on_attach
    }, opts or {})
    vim.lsp.start(opts)
end

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

-- Custom :LspInfo command to show all attached LSP clients and their capabilities for the current buffer in a floating scratch buffer
vim.api.nvim_create_user_command("LspInfo", function()
    local clients = vim.lsp.get_clients({
        bufnr = 0
    })
    local lines = {}
    local function add_lines(str)
        for _, l in ipairs(vim.split(str, "\n")) do
            table.insert(lines, l)
        end
    end
    if #clients == 0 then
        add_lines("No LSP clients attached to this buffer.")
    else
        add_lines("LSP clients attached to buffer " .. vim.api.nvim_get_current_buf() .. ":")
        add_lines("")
        for _, client in ipairs(clients) do
            add_lines(client.name)
            add_lines("Capabilities:")
            for k, v in pairs(client.server_capabilities or {}) do
                local v_lines = vim.split(vim.inspect(v), "\n")
                add_lines(k .. ": " .. v_lines[1])
                for i = 2, #v_lines do
                    add_lines("  " .. v_lines[i])
                end
            end
            add_lines("")
        end
    end
    -- Create a scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- Floating window config (bigger size)
    local width = math.min(160, math.max(80, math.floor(vim.o.columns * 0.85)))
    local height = math.min(40, #lines + 4)
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded"
    }
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "filetype", "typescript")
    vim.keymap.set("n", "q", function()
        pcall(vim.api.nvim_win_close, win, true)
    end, {
        buffer = buf,
        nowait = true
    })
end, {})

-- Custom :LspRestart command to restart all LSP clients attached to the current buffer
vim.api.nvim_create_user_command("LspRestart", function()
    local clients = vim.lsp.get_clients({
        bufnr = 0
    })
    if #clients == 0 then
        print("No LSP clients to restart for this buffer.")
        return
    end
    for _, client in ipairs(clients) do
        if client and client.stop then
            client.stop(true) -- true = restart
            print("Restarted LSP client: " .. client.name)
        end
    end
end, {})

return M
