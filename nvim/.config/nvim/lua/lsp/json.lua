vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc" },
	callback = function(args)
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		vim.bo.softtabstop = 4
		vim.bo.expandtab = true

		local lsp = require("core.lsp")
		local fname = vim.api.nvim_buf_get_name(args.buf or 0)

		local schemas = {}
		local ok, schemastore = pcall(require, "schemastore")
		if ok then
			schemas = schemastore.json.schemas()
		end

		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities.textDocument.completion.completionItem.snippetSupport = true

		lsp.setup_lsp({
			name = "jsonls",
			cmd = { "vscode-json-language-server", "--stdio" },
			init_options = { provideFormatter = true },
			root_dir = lsp.resolve_root({
				path = fname,
				patterns = { ".git", "package.json" },
			}),
			settings = {
				json = {
					validate = { enable = true },
					format = { enable = true },
					schemas = schemas,
					schemaStore = {
						enable = false,
						url = "https://www.schemastore.org/api/json/catalog.json",
					},
				},
				-- 👇 This is the magic bit jsonls actually respects
				["json.format.enable"] = true,
				["editor.tabSize"] = 4,
				["editor.insertSpaces"] = true,
			},
			capabilities = capabilities,
			single_file_support = true,
		})
	end,
})
