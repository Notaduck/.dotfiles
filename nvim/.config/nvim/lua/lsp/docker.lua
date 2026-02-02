vim.api.nvim_create_autocmd("FileType", {
	pattern = { "dockerfile" },
	callback = function(args)
		local lsp = require("core.lsp")
		local fname = vim.api.nvim_buf_get_name(args.buf or 0)
		lsp.setup_lsp({
			name = "dockerls",
			cmd = { "docker-langserver", "--stdio" },
			root_dir = lsp.resolve_root({
				path = fname,
				patterns = { ".git", "Dockerfile", "docker-compose.yml", "docker-compose.yaml" },
			}),
		})
	end,
})

-- Docker Compose LSP (separate from Dockerfile LSP)
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "yaml", "yml" },
	callback = function(args)
		local bufname = vim.api.nvim_buf_get_name(args.buf or 0)
		local filename = vim.fn.fnamemodify(bufname, ":t")
		-- Only attach if file appears to be a docker-compose file
		if not filename:match("docker%-compose") and not filename:match("docker%.") then
			return
		end
		local lsp = require("core.lsp")
		lsp.setup_lsp({
			name = "docker_compose_language_service",
			cmd = { "docker-compose-langserver", "--stdio" },
			root_dir = lsp.resolve_root({
				path = bufname,
				patterns = { ".git", "docker-compose.yml", "docker-compose.yaml" },
			}),
		})
	end,
})
