local lint_settings = {
	validate = true,
	lint = {
		unknownAtRules = "ignore", -- For Tailwind @apply etc.
	},
}

vim.lsp.config("cssls", {
	cmd = { "vscode-css-language-server", "--stdio" },
	filetypes = { "css", "scss", "less" },
	root_markers = { "package.json", ".git" },
	settings = {
		css = lint_settings,
		scss = lint_settings,
		less = lint_settings,
	},
})
vim.lsp.enable("cssls")
