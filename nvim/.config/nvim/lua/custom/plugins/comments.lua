-- File: ~/.config/nvim/lua/plugins/comment.lua

-- 2. Plugin Configuration
return {
	"numToStr/Comment.nvim",
	dependencies = {
		"JoosepAlviste/nvim-ts-context-commentstring",
	},

	config = function()
		-- Set comment string for 'dotenv' filetype
		require("Comment.ft").set("dotenv", { "# %s" })

		require("Comment").setup({
			pre_hook = function(ctx)
				-- Only calculate comment string for 'dotenv' filetype
				if vim.bo.filetype == "dotenv" then
					return require("Comment.utils").toggle_commentstring("# %s", nil)
				end

				-- Use the default pre_hook for other filetypes
				return require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()(ctx)
			end,
			-- Optional: Additional configuration options
			-- ignore = nil,
			-- mappings = {
			--     basic = true,
			--     extra = false,
			-- },
			-- etc.
		})
	end,
}
