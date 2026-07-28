-- JSON indent prefs
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc" },
	group = vim.api.nvim_create_augroup("UserJsonIndent", { clear = true }),
	callback = function()
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		vim.bo.softtabstop = 4
		vim.bo.expandtab = true
	end,
})

local schemas = {}
local ok, schemastore = pcall(require, "schemastore")
if ok then
	schemas = schemastore.json.schemas()
end

vim.lsp.config("jsonls", {
	cmd = { "vscode-json-language-server", "--stdio" },
	filetypes = { "json", "jsonc" },
	root_markers = { ".git", "package.json" },
	init_options = { provideFormatter = true },
	settings = {
		json = {
			validate = { enable = true },
			format = { enable = true },
			schemas = schemas,
			schemaStore = {
				enable = false, -- Use schemastore.nvim instead
				url = "https://www.schemastore.org/api/json/catalog.json",
			},
		},
	},
})
vim.lsp.enable("jsonls")
