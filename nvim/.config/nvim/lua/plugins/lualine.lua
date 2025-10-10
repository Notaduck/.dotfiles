-- stylua: ignore
local colors = {
  blue = '#286983',
  cyan = '#56949f',
  black = '#faf4ed',
  white = '#6e6a86',
  red = '#b4637a',
  violet = '#907aa9',
  grey = '#d9d7e0'
}

local bubbles_theme = {
	normal = {
		a = { fg = colors.black, bg = colors.violet },
		b = { fg = colors.white, bg = colors.grey },
		c = { fg = colors.white },
	},
	insert = {
		a = { fg = colors.black, bg = colors.blue },
	},
	visual = {
		a = { fg = colors.black, bg = colors.cyan },
	},
	replace = {
		a = { fg = colors.black, bg = colors.red },
	},
	inactive = {
		a = { fg = colors.white, bg = colors.black },
		b = { fg = colors.white, bg = colors.black },
		c = { fg = colors.white },
	},
}

return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"rose-pine/neovim",
		"github/copilot.vim", -- or whatever provides Sidekick
	},
	config = function()
		-- Custom Treesitter context
		local function treesitter_context()
			local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
			local parsers_ok, parsers = pcall(require, "nvim-treesitter.parsers")
			if not ok or not parsers_ok then
				return ""
			end
			local bufnr = vim.api.nvim_get_current_buf()
			if not parsers.has_parser() then
				return ""
			end
			local cursor_node = ts_utils.get_node_at_cursor()
			if not cursor_node then
				return ""
			end

			local function find_parent(node, types)
				while node do
					if vim.tbl_contains(types, node:type()) then
						return node
					end
					node = node:parent()
				end
				return nil
			end

			local class_types = { "class_declaration", "class", "class_definition" }
			local func_types = {
				"function_declaration",
				"method_definition",
				"function",
				"function_definition",
				"method",
				"function_statement",
			}

			local class_node = find_parent(cursor_node, class_types)
			local func_node = find_parent(cursor_node, func_types)

			local function get_name(node)
				if not node then
					return ""
				end
				local name_node = node:field("name") and node:field("name")[1]
				if name_node then
					return vim.treesitter.get_node_text(name_node, bufnr)
				end
				if node:type() == "method_definition" then
					local key_node = node:field("property") and node:field("property")[1]
					if key_node then
						return vim.treesitter.get_node_text(key_node, bufnr)
					end
				end
				return ""
			end

			local class_name = get_name(class_node)
			local func_name = get_name(func_node)

			if class_name ~= "" and func_name ~= "" then
				return class_name .. "." .. func_name .. "()"
			elseif func_name ~= "" then
				return func_name .. "()"
			else
				return ""
			end
		end

		-- LSP status function
		local function lsp_status()
			local clients = vim.lsp.get_clients({ bufnr = 0 })
			if #clients == 0 then
				return ""
			end
			local client_names = {}
			for _, client in ipairs(clients) do
				table.insert(client_names, client.name)
			end
			return " " .. table.concat(client_names, ", ")
		end

		-- 🔹 Sidekick status component (DieKick integration)
		local sidekick_component = {
			function()
				return " "
			end,
			color = function()
				local status = require("sidekick.status").get()
				if status then
					if status.kind == "Error" then
						return { fg = vim.fn.synIDattr(vim.fn.hlID("DiagnosticError"), "fg") }
					elseif status.busy then
						return { fg = vim.fn.synIDattr(vim.fn.hlID("DiagnosticWarn"), "fg") }
					else
						return { fg = vim.fn.synIDattr(vim.fn.hlID("Special"), "fg") }
					end
				end
			end,
			cond = function()
				local status = require("sidekick.status").get()
				return status ~= nil
			end,
		}

		require("lualine").setup({
			options = {
				theme = bubbles_theme,
				component_separators = "",
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = {
					{ "mode", separator = { left = "" }, right_padding = 2 },
				},
				lualine_b = { "filename", "branch" },
				-- 🧩 Insert Sidekick into lualine_c
				lualine_c = { "%=", treesitter_context, sidekick_component },
				lualine_x = { lsp_status },
				lualine_y = { "filetype", "progress" },
				lualine_z = {
					{ "location", separator = { right = "" }, left_padding = 2 },
				},
			},
			inactive_sections = {
				lualine_a = { "filename" },
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "location" },
			},
		})
	end,
}
