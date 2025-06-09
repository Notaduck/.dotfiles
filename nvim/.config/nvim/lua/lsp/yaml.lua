vim.api.nvim_create_autocmd("FileType", {
    pattern = {"yaml", "yml"},
    callback = function()
        vim.lsp.start({
            name = "yaml-language-server",
            cmd = {"yaml-language-server", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "docker-compose.yml", "docker-compose.yaml"}, {
                upward = true
            })[1] or ""),
            settings = {
                yaml = {
                    schemas = {
                        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
                        ["https://json.schemastore.org/github-action.json"] = "/.github/actions/*/action.yml",
                        ["https://json.schemastore.org/docker-compose.json"] = "docker-compose*.{yml,yaml}",
                        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.{yml,yaml}",
                        ["https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json"] = "*k8s*.{yml,yaml}"
                    },
                    validate = true,
                    format = {
                        enable = true
                    },
                    hover = true,
                    completion = true
                },
                redhat = {
                    telemetry = {
                        enabled = false
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
