vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"lua"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
            name = "lua_ls",
            cmd = {"lua-language-server"},
            root_dir = vim.fs.dirname(vim.fs.find({".git", "init.lua"}, {
                upward = true
            })[1] or ""),
            settings = {
                Lua = {
                    runtime = {
                        version = 'LuaJIT'
                    },
                    diagnostics = {
                        globals = {'vim'}
                    },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false
                    },
                    telemetry = {
                        enable = false
                    },
                    hint = {
                        enable = true,
                        paramName = "Literal",
                        paramType = true,
                        setType = true
                    }
                }
            }
        })
    end
})
