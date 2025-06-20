vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"go"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
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
            }
        })
    end
})
