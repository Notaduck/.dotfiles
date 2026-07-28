-- YAML LSP configuration
-- Skips docker-compose* files so docker_compose_language_service can attach.

local function is_docker_compose(bufnr)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	local basename = vim.fn.fnamemodify(fname, ":t")
	return basename:match("docker%-compose") ~= nil or basename:match("docker%.") ~= nil
end

local schemas = {}
local ok, schemastore = pcall(require, "schemastore")
if ok then
	schemas = schemastore.yaml.schemas()
end

vim.lsp.config("yamlls", {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml" },
	root_dir = function(bufnr, on_dir)
		if is_docker_compose(bufnr) then
			return -- skip; docker_compose_language_service handles these
		end
		local fname = vim.api.nvim_buf_get_name(bufnr)
		local root = vim.fs.root(fname, { ".git", "package.json", "helmfile.yaml", "Chart.yaml" })
		on_dir(root or vim.fn.getcwd())
	end,
	settings = {
		yaml = {
			validate = true,
			hover = true,
			completion = true,
			format = { enable = true },
			keyOrdering = false,
			schemas = schemas,
			schemaStore = {
				enable = false, -- Use schemastore.nvim instead to avoid network fetch each start
				url = "https://www.schemastore.org/api/json/catalog.json",
			},
		},
	},
})
vim.lsp.enable("yamlls")
