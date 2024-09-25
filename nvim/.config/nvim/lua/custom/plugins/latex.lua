return {
	"lervag/vimtex",
	lazy = true, -- we don't want to lazy load VimTeX -- but I really do
	ft = { "tex", "bbl", "cls" },
	-- tag = "v2.15", -- uncomment to pin to a specific release
	init = function()
		-- VimTeX configuration goes here, e.g.
		vim.g.vimtex_view_method = "zathura"
	end,
}
