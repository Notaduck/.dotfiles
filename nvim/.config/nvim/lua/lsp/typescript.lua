vim.api.nvim_create_autocmd({"FileType", "BufEnter"}, {
    pattern = {"typescript", "typescriptreact", "javascript", "javascriptreact"},
    callback = function()
        local lsp = require("core.lsp")
        lsp.setup_lsp({
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
            }
        })
    end
})
