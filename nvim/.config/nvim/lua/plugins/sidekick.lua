return {
	"folke/sidekick.nvim",
	opts = {
		nes = {
			---@type boolean|fun(buf:integer):boolean?
			enabled = true,
		},
		-- add any options here
		cli = {
			mux = {
				backend = "tmux",
				enabled = true,
			},
		},
	},
   -- stylua: ignore
   keys = {
     {
       "<tab>",
       function()
         -- if there is a next edit, jump to it, otherwise apply it if any
         if not require("sidekick").nes_jump_or_apply() then
           return "<Tab>" -- fallback to normal tab
         end
       end,
       expr = true,
       desc = "Goto/Apply Next Edit Suggestion",
     },
     -- <leader>a* bindings removed to avoid conflicts with avante.nvim.
     -- Use the sidekick.cli API directly if needed.
     {
       "<c-.>",
       function() require("sidekick.cli").focus() end,
       mode = { "n", "x", "i", "t" },
       desc = "Sidekick Switch Focus",
     },
   },
	dependencies = {
		-- Make sure to set this up properly if you have lazy=true
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {
			file_types = { "markdown", "Avante" },
		},
		ft = { "markdown", "Avante" },
	},
}
