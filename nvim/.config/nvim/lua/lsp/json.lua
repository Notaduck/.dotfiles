vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"json", "jsonc"},
    callback = function()
        vim.lsp.start({
            name = "jsonls",
            cmd = {"vscode-json-language-server", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "package.json"}, {
                upward = true
            })[1] or ""),
            settings = {
                json = {
                    schemas = require('schemastore').json.schemas(),
                    validate = {
                        enable = true
                    },
                    format = {
                        enable = true
                    }
                }
            },
            capabilities = (function()
                local capabilities = vim.lsp.protocol.make_client_capabilities()
                capabilities.textDocument.completion.completionItem.snippetSupport = true
                return capabilities
            end)(),
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
