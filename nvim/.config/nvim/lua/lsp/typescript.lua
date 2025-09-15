local patterns = { typescript = true, typescriptreact = true, javascript = true, javascriptreact = true }

local function start_ts_lsp(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	local ft = vim.bo[bufnr].filetype
	if not patterns[ft] then return end
	if pcall(vim.api.nvim_buf_get_var, bufnr, "_ts_lsp_started") then return end
	vim.api.nvim_buf_set_var(bufnr, "_ts_lsp_started", true)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	if fname == "" then return end
	local lsp = require("core.lsp")
	local root = vim.fs.dirname(vim.fs.find({ "package.json", "tsconfig.json", ".git" }, { path = vim.fs.dirname(fname), upward = true })[1] or vim.loop.cwd())
	local use_vtsls = vim.fn.executable("vtsls") == 1
	local cmd = use_vtsls and { "vtsls", "--stdio" } or { "typescript-language-server", "--stdio" }
	local name = use_vtsls and "vtsls" or "tsserver"
		if not use_vtsls and vim.fn.executable("typescript-language-server") == 0 then
			vim.notify("TypeScript LSP: neither vtsls nor typescript-language-server found in PATH", vim.log.levels.ERROR)
		return
	end
	lsp.setup_lsp({
		name = name,
		cmd = cmd,
		root_dir = root,
		settings = {
			typescript = {
				format = {
					semicolons = "remove",
					preferSingleQuotes = true,
					insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
					insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
					insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
					insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false,
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
						includeCompletionsWithInsertText = true,
				},
				inlayHints = {
					parameterNames = { enabled = "all" },
					parameterTypes = { enabled = true },
					variableTypes = { enabled = true },
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
