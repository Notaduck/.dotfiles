-- Dockerfile LSP
vim.lsp.config("dockerls", {
	cmd = { "docker-langserver", "--stdio" },
	filetypes = { "dockerfile" },
	root_markers = { "Dockerfile", ".git" },
})
vim.lsp.enable("dockerls")

-- docker-compose LSP (attaches only to docker-compose yaml files)
local function is_docker_compose(bufnr)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	local basename = vim.fn.fnamemodify(fname, ":t")
	return basename:match("docker%-compose") ~= nil or basename:match("docker%.") ~= nil
end

vim.lsp.config("docker_compose_language_service", {
	cmd = { "docker-compose-langserver", "--stdio" },
	filetypes = { "yaml" },
	root_dir = function(bufnr, on_dir)
		if not is_docker_compose(bufnr) then
			return
		end
		local fname = vim.api.nvim_buf_get_name(bufnr)
		local root = vim.fs.root(fname, { "docker-compose.yml", "docker-compose.yaml", ".git" })
		on_dir(root or vim.fn.getcwd())
	end,
})
vim.lsp.enable("docker_compose_language_service")
