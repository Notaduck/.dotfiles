vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"dockerfile"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
            name = "dockerls",
            cmd = {"docker-langserver", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "Dockerfile", "docker-compose.yml", "docker-compose.yaml"}, {
                upward = true
            })[1] or "")
        })
    end
})

-- Docker Compose LSP (separate from Dockerfile LSP)
vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"yaml", "yml"},
    callback = function()
        -- Only attach if file appears to be a docker-compose file
        local filename = vim.fn.expand("%:t")
        if not filename:match("docker%-compose") and not filename:match("docker%.") then
            return
        end
        local lsp = require("core.lsp")
        lsp.setup_lsp({
            name = "docker_compose_language_service",
            cmd = {"docker-compose-langserver", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "docker-compose.yml", "docker-compose.yaml"}, {
                upward = true
            })[1] or "")
        })
    end
})
