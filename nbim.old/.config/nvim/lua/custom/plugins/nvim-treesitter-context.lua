return {

	"nvim-treesitter/nvim-treesitter-context",
	-- Optionally, you can set when to load the plugin. Here, it's loaded after Treesitter is set up.
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("treesitter-context").setup({
			-- Configuration options (optional)
			enable = true, -- Enable this plugin
			max_lines = 1, -- How many lines the context window should span. 0 means no limit
			min_window_height = 0, -- Minimum editor window height to enable context. 0 means no limit
			line_numbers = true, -- Show line numbers in the context window
			multiline_threshold = 20, -- Maximum number of lines to show for a single context
			trim_scope = "outer", -- Which context lines to discard if `max_lines` is exceeded
			mode = "cursor", -- Line used to calculate context. Choices: 'cursor', 'topline'
			separator = nil, -- Separator between context and content. Should be a single character string, like '-'
			zindex = 20, -- The Z-index of the context window
			on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
		})
	end,
}
