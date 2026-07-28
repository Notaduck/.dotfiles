-- ESLint LSP via vscode-eslint-language-server.
-- Always resolves eslint from the project's own node_modules, not a global install.

if vim.fn.executable("vscode-eslint-language-server") ~= 1 then
	vim.notify("ESLint LSP: vscode-eslint-language-server not found. Run :MasonInstall eslint-lsp", vim.log.levels.WARN)
	return
end

vim.lsp.config("eslint", {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},
	root_markers = {
		"eslint.config.js",
		"eslint.config.mjs",
		"eslint.config.cjs",
		".eslintrc.js",
		".eslintrc.cjs",
		".eslintrc.yaml",
		".eslintrc.yml",
		".eslintrc.json",
		".eslintrc",
		"package.json",
	},
	settings = {
		validate = "on",
		-- Resolve eslint from the project's node_modules, not a global binary.
		packageManager = "npm",
		useESLintClass = false,
		experimental = { useFlatConfig = false },
		codeActionOnSave = { enable = false },
		format = false,
		quiet = false,
		onIgnoredFiles = "off",
		rulesCustomizations = {},
		run = "onType",
		problems = { shortenToSingleLine = false },
		-- Auto-detect per-folder working directory (important for monorepos).
		workingDirectories = { { mode = "auto" } },
		nodePath = "",
	},
	before_init = function(params)
		-- Point the server at the workspace root so it resolves the local eslint.
		params.processId = vim.uv.os_getpid()
	end,
})

vim.lsp.enable("eslint")

-- Apply all ESLint auto-fixes on save (runs after conform formats).
vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("UserEslintFixOnSave", { clear = true }),
	pattern = { "*.js", "*.jsx", "*.ts", "*.tsx", "*.mjs", "*.cjs" },
	callback = function()
		local clients = vim.lsp.get_clients({ name = "eslint" })
		if #clients == 0 then
			return
		end
		vim.lsp.buf.code_action({
			context = { only = { "source.fixAll.eslint" }, diagnostics = {} },
			apply = true,
		})
	end,
})
