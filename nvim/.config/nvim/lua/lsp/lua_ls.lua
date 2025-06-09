vim.api.nvim_create_autocmd("FileType", {
    pattern = {"lua"},
    callback = function()
        vim.lsp.start({
            name = "lua_ls",
            cmd = {"lua-language-server"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "init.lua"}, {
                upward = true
            })[1] or ""),
            settings = {
                Lua = {
                    runtime = {
                        version = 'LuaJIT'
                    },
                    diagnostics = {
                        globals = {'vim'}
                    },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false
                    },
                    telemetry = {
                        enable = false
                    },
                    hint = {
                        enable = true,
                        paramName = "Literal",
                        paramType = true,
                        setType = true
                    }
                }
            },
            on_attach = function(client, bufnr)
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
        })
    end
})
