vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"json", "jsonc"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
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
            end)()
        })
    end
})
