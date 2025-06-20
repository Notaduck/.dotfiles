vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"typescript", "typescriptreact", "javascript", "javascriptreact"},
    callback = function()
        vim.lsp.start({
            name = "vtsls",
            cmd = {"vtsls", "--stdio"},
            root_dir = vim.fs.dirname(vim.fs.find({"package.json", "tsconfig.json", ".git"}, {
                upward = true
            })[1]),
            settings = {
                typescript = {
                    format = {
                        semicolons = "remove",
                        preferSingleQuotes = true,
                        insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
                        insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
                        insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
                        insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false
                    },
                    preferences = {
                        importModuleSpecifier = "non-relative",
                        quoteStyle = "single",
                        includeCompletionsForImportStatements = true,
                        generateReturnInDocTemplate = true,
                        includeAutomaticOptionalChainCompletions = true,
                        allowRenameOfImportPath = true,
                        allowTextChangesInNewFiles = true,
                        includeCompletionsWithSnippetText = true,
                        includeCompletionsWithClassMemberSnippets = true,
                        includeCompletionsWithInsertText = true
                    },
                    inlayHints = {
                        parameterNames = {
                            enabled = "all"
                        },
                        parameterTypes = {
                            enabled = true
                        },
                        variableTypes = {
                            enabled = true
                        },
                        propertyDeclarationTypes = {
                            enabled = true
                        },
                        functionLikeReturnTypes = {
                            enabled = true
                        },
                        enumMemberValues = {
                            enabled = true
                        }
                    }
                }
            },
            single_file_support = true,
            autostart = true,
            reuse_client = function(client, config)
                return client.name == config.name and client.config.root_dir == config.root_dir
            end,
            on_attach = function(client, bufnr)

                -- Enable inlay hints immediately
                if client.supports_method("textDocument/inlayHint") then
                    vim.lsp.inlay_hint.enable(true, {
                        bufnr = bufnr
                    })
                else
                    print("❌ vtsls doesn't support inlay hints")
                end

                -- Add toggle keymap
                vim.keymap.set('n', '<leader>th', function()
                    local current = vim.lsp.inlay_hint.is_enabled({
                        bufnr = bufnr
                    })
                    vim.lsp.inlay_hint.enable(not current, {
                        bufnr = bufnr
                    })
                    print("🔄 Inlay hints " .. (current and "disabled" or "enabled"))
                end, {
                    buffer = bufnr,
                    desc = '[T]oggle Inlay [H]ints'
                })
            end
        })
    end
})
