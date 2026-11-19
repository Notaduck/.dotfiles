return {
	{
		"saghen/blink.cmp",
		dependencies = { "rafamadriz/friendly-snippets" },
		version = "*",
		config = function()
			require("blink.cmp").setup({
				snippets = {
					preset = "default", -- vim.snippet + friendly-snippets
				},
				signature = {
					enabled = true,
					window = {
						border = "rounded",
						max_width = 80,
						max_height = 20,
						-- Match your theme
						winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder",
					},
				},
				appearance = {
					use_nvim_cmp_as_default = false,
					-- nerd_font_variant = "normal",
					nerd_font_variant = "mono",
				},
				sources = {
					default = { "lsp", "path", "snippets", "buffer" },
					providers = {
						cmdline = {
							enabled = true,
							min_keyword_length = 2,
						},
					},
				},
				keymap = {
					["<C-f>"] = {},
					["<CR>"] = { "accept", "fallback" },
					-- ["<Tab>"] = {
					-- 	function(cmp)
					-- 		return cmp.select_next()
					-- 	end,
					-- 	"snippet_forward",
					-- 	"fallback",
					-- },
					-- ["<S-Tab>"] = {
					-- 	function(cmp)
					-- 		return cmp.select_prev()
					-- 	end,
					-- 	"snippet_backward",
					-- 	"fallback",
					-- },

					-- Let arrow keys prefer completion navigation, but still handle snippets if active.
					["<Up>"] = {
						function(cmp)
							return cmp.select_prev()
						end,
						"snippet_backward",
						"fallback",
					},
					["<Down>"] = {
						function(cmp)
							return cmp.select_next()
						end,
						"snippet_forward",
						"fallback",
					},
				},
				cmdline = {
					enabled = false,
					completion = {
						ghost_text = { enabled = true },
						menu = {
							auto_show = true,
						},
					},
					keymap = {
						["<CR>"] = { "accept_and_enter", "fallback" },
					},
				},
				completion = {
					menu = {
						border = "single",
						scrolloff = 1,
						scrollbar = false,
						winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
						draw = {
							padding = 4,
							columns = {
								{ "label" },
								{ "kind_icon", "kind" }, -- { "kind_icon" },
							},
						},
					},
					documentation = {
						window = {
							border = "single",
							scrollbar = false,
							winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
						},
						auto_show = true,
						auto_show_delay_ms = 500,
					},
				},
			})
		end,
	},
}
