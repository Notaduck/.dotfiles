vim.lsp.config("gopls", {
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gowork" },
	root_markers = { "go.work", "go.mod", ".git" },
	settings = {
		gopls = {
			analyses = {
				unusedparams = true,
				shadow = true,
			},
			staticcheck = true,
			gofumpt = true,
			hints = {
				parameterNames = true,
				functionTypeParameters = true,
				constantValues = true,
				rangeVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				assignVariableTypes = true,
			},
		},
	},
})
vim.lsp.enable("gopls")
