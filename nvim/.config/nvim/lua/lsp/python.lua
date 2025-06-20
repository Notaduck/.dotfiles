vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"python"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
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
            }
        })
    end
})
