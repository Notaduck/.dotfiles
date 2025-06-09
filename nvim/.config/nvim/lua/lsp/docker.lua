vim.api.nvim_create_autocmd("FileType", {
    pattern = {"dockerfile"},
    callback = function()
        vim.lsp.start({
            name = "dockerls",
            cmd = {"docker-langserver", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "Dockerfile", "docker-compose.yml", "docker-compose.yaml"}, {
                upward = true
            })[1] or ""),
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

-- Docker Compose LSP (separate from Dockerfile LSP)
vim.api.nvim_create_autocmd("FileType", {
    pattern = {"yaml", "yml"},
    callback = function()
        -- Only attach if file appears to be a docker-compose file
        local filename = vim.fn.expand("%:t")
        if not filename:match("docker%-compose") and not filename:match("docker%.") then
            return
        end

        vim.lsp.start({
            name = "docker_compose_language_service",
            cmd = {"docker-compose-langserver", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "docker-compose.yml", "docker-compose.yaml"}, {
                upward = true
            })[1] or ""),
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
