return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false,
	priority = 1000,
	opts = {
		flavour = "mocha",
		-- Leave the editor background to the terminal: Tern's window is
		-- translucent, so an opaque base colour shows as a lighter box there.
		-- Ghostty paints the same Mocha base, so it looks identical. Floats
		-- keep their own (mantle) background.
		transparent_background = true,
		integrations = {
			blink_cmp = true,
			diffview = true,
			fidget = true,
			gitsigns = true,
			lsp_trouble = true,
			mason = true,
			mini = { enabled = true },
			noice = true,
			render_markdown = true,
			snacks = { enabled = true },
			treesitter = true,
			treesitter_context = true,
			which_key = true,
			native_lsp = {
				enabled = true,
				underlines = {
					errors = { "undercurl" },
					hints = { "undercurl" },
					warnings = { "undercurl" },
					information = { "undercurl" },
				},
			},
		},
	},
}
