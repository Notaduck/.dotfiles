local patterns = { typescript = true, typescriptreact = true, javascript = true, javascriptreact = true }

local function start_ts_lsp(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	local ft = vim.bo[bufnr].filetype
	if not patterns[ft] then
		return
	end
	if pcall(vim.api.nvim_buf_get_var, bufnr, "_ts_lsp_started") then
		return
	end
	vim.api.nvim_buf_set_var(bufnr, "_ts_lsp_started", true)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	if fname == "" then
		return
	end
	local lsp = require("core.lsp")
	local root = lsp.resolve_root({
		path = fname,
		patterns = { "package.json", "tsconfig.json", ".git" },
	})
	local cmd = { "tsgo", "--lsp", "--stdio" }
	local name = "tsgo"
	if vim.fn.executable("tsgo") == 0 then
		vim.notify("TypeScript LSP: tsgo not found in PATH. Install via :MasonInstall tsgo", vim.log.levels.ERROR)
		return
	end
	local format_options = {
		semicolons = "remove",
		insertSpaceAfterCommaDelimiter = true,
		insertSpaceAfterSemicolonInForStatements = true,
		insertSpaceBeforeAndAfterBinaryOperators = true,
		insertSpaceAfterConstructor = false,
		insertSpaceAfterKeywordsInControlFlowStatements = true,
		insertSpaceAfterFunctionKeywordForAnonymousFunctions = true,
		insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
		insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
		insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
		insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false,
		insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = false,
		insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = false,
		insertSpaceBeforeFunctionParenthesis = false,
		placeOpenBraceOnNewLineForFunctions = false,
		placeOpenBraceOnNewLineForControlBlocks = false,
		indentMultiLineObjectLiteralBeginningOnBlankLine = true,
	}
	local preferences = {
		quotePreference = "single",
		importModuleSpecifierPreference = "non-relative",
		importModuleSpecifierEnding = "minimal",
		includeCompletionsForImportStatements = true,
		generateReturnInDocTemplate = true,
		includeAutomaticOptionalChainCompletions = true,
		allowRenameOfImportPath = true,
		allowTextChangesInNewFiles = true,
		includeCompletionsWithSnippetText = true,
		includeCompletionsWithClassMemberSnippets = true,
		includeCompletionsWithInsertText = true,
	}
	lsp.setup_lsp({
		name = name,
		cmd = cmd,
		root_dir = root,
		init_options = {
			preferences = preferences,
		},
		settings = {
			typescript = {
				format = format_options,
				preferences = preferences,
				inlayHints = {
					parameterNames = { enabled = "all" },
					parameterTypes = { enabled = true },
					variableTypes = { enabled = false },
					propertyDeclarationTypes = { enabled = true },
					functionLikeReturnTypes = { enabled = true },
					enumMemberValues = { enabled = true },
				},
			},
			javascript = {
				format = format_options,
				preferences = preferences,
				inlayHints = {
					parameterNames = { enabled = "all" },
					parameterTypes = { enabled = true },
					variableTypes = { enabled = false },
					propertyDeclarationTypes = { enabled = true },
					functionLikeReturnTypes = { enabled = true },
					enumMemberValues = { enabled = true },
				},
			},
		},
	})
end

-- Start for existing buffers now
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	start_ts_lsp(b)
end

-- And for future buffers/filetype changes
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
	callback = function(args)
		start_ts_lsp(args.buf)
	end,
})
