vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"python"},
    callback = function()
        vim.lsp.start({
            name = "pyright",
            cmd = {"pyright-langserver", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "pyproject.toml", "setup.py", "requirements.txt"}, {
                upward = true
            })[1] or ""),
            settings = {
                python = {
                    analysis = {
                        typeCheckingMode = "basic",
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "workspace"
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
