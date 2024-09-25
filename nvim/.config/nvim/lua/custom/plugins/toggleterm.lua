return {
	-- Your other plugins
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("toggleterm").setup({
				-- Any specific configurations for toggleterm go here
				open_mapping = [[<C-j>]], -- This sets the default keybinding for opening the terminal
				direction = "float",
			})
		end,
		-- Alternatively, you can specify the keybinding separately
		keys = {
			{ "<C-j>", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
		},
	},
	-- Other plugins...
}
