vim.api.nvim_create_autocmd("FileType", {
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
