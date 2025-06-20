vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"go"},
    callback = function()
        vim.lsp.start({
            name = "gopls",
            cmd = {"gopls"},
            root_dir = vim.fs.dirname(vim.fs.find({"go.mod", ".git"}, {
                upward = true
            })[1] or ""),
            settings = {
                gopls = {
                    analyses = {
                        unusedparams = true,
                        shadow = true
                    },
                    staticcheck = true,
                    gofumpt = true,
                    hints = {
                        parameterNames = true,
                        functionTypeParameters = true,
                        constantValues = true,
                        rangeVariableTypes = true,
                        compositeLiteralFields = true,
                        compositeLiteralTypes = true,
                        assignVariableTypes = true
                    }
                }
            },
            single_file_support = true,
            autostart = true,
            reuse_client = function(client, config)
                return client.name == config.name and client.config.root_dir == config.root_dir
            end,
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
