-- GitHub Actions workflow LSP
-- Treats .github/workflows/*.{yml,yaml} as filetype `yaml.gha` so both yamlls
-- (via the `yaml` ft branch) and gh_actions_ls (via `gha`) can attach.

vim.filetype.add({
	pattern = {
		[".*/%.github/workflows/[^/]+%.ya?ml"] = "yaml.gha",
		[".*/%.gitea/workflows/[^/]+%.ya?ml"] = "yaml.gha",
	},
})

vim.lsp.config("gh_actions_ls", {
	cmd = { "gh-actions-language-server", "--stdio" },
	filetypes = { "yaml.gha" },
	root_markers = { ".github", ".git" },
	init_options = {
		-- sessionToken can be set via GITHUB_TOKEN env var for private repos
	},
})
vim.lsp.enable("gh_actions_ls")
