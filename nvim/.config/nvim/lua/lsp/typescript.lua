-- TypeScript/JavaScript LSP — prefers tsgo, falls back to ts_ls.

local cmd, name
if vim.fn.executable("tsgo") == 1 then
	cmd = { "tsgo", "--lsp", "--stdio" }
	name = "tsgo"
elseif vim.fn.executable("typescript-language-server") == 1 then
	cmd = { "typescript-language-server", "--stdio" }
	name = "ts_ls"
else
	vim.notify(
		"TypeScript LSP: no server found. Install tsgo or typescript-language-server",
		vim.log.levels.WARN
	)
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

local inlay_hints = {
	parameterNames = { enabled = "all" },
	parameterTypes = { enabled = true },
	variableTypes = { enabled = false },
	propertyDeclarationTypes = { enabled = true },
	functionLikeReturnTypes = { enabled = true },
	enumMemberValues = { enabled = true },
}

vim.lsp.config(name, {
	cmd = cmd,
	filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	settings = {
		typescript = {
			format = format_options,
			preferences = preferences,
			inlayHints = inlay_hints,
		},
		javascript = {
			format = format_options,
			preferences = preferences,
			inlayHints = inlay_hints,
		},
	},
})
vim.lsp.enable(name)
