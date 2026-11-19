-- Filetypes formatted automatically on save
local format_on_save_ft = {
	javascript = true,
	javascriptreact = true,
	typescript = true,
	typescriptreact = true,
	lua = true,
	python = true,
	go = true,
}

local function format(bufnr)
	require("conform").format({
		bufnr = bufnr,
		timeout_ms = 3000,
		lsp_format = "fallback",
	})
end

return {
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		keys = {
			{ "<leader>cf", function() format() end, mode = { "n", "v" }, desc = "Format Buffer" },
			{ "<leader>fm", function() format() end, mode = { "n", "v" }, desc = "Format file or range" },
		},
		opts = {
			formatters_by_ft = {
				-- JavaScript/TypeScript
				javascript = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },

				-- Add Lua formatting
				lua = { "stylua" },

				-- Python (both run in sequence)
				python = { "isort", "black" },

				-- Go (goimports also applies gofmt formatting)
				go = { "goimports" },

				-- JSON
				json = { "jq" },
				jsonc = { "jq" },
			},
			formatters = {
				-- Personal style (no semicolons, single quotes) applies only when the
				-- project has no prettier config of its own.
				prettier = {
					prepend_args = { "--config-precedence", "prefer-file", "--no-semi", "--single-quote" },
				},
				prettierd = {
					env = {
						PRETTIERD_DEFAULT_CONFIG = vim.fn.stdpath("config") .. "/.prettierrc.json",
					},
				},
			},
			format_on_save = function(bufnr)
				if not format_on_save_ft[vim.bo[bufnr].filetype] then
					return
				end
				return { timeout_ms = 1500, lsp_format = "fallback" }
			end,
		},
	},
}
