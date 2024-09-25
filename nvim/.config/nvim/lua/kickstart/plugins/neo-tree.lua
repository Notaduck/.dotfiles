-- -- Neo-tree is a Neovim plugin to browse the file system
-- -- https://github.com/nvim-neo-tree/neo-tree.nvim
--
-- return {
--   'nvim-neo-tree/neo-tree.nvim',
--   version = '*',
--   dependencies = {
--     'nvim-lua/plenary.nvim',
--     'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
--     'MunifTanjim/nui.nvim',
--   },
--   cmd = 'Neotree',
--   keys = {
--     { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
--   },
--   opts = {
--     filesystem = {
--       window = {
--         mappings = {
--           ['\\'] = 'close_window',
--         },
--       },
--     },
--   },
-- }
-- Neo-tree setup with custom quit behavior
return {
	"nvim-neo-tree/neo-tree.nvim",
	version = "*",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	cmd = "Neotree",
	keys = {
		{ "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
	},
	opts = {
		filesystem = {
			window = {
				mappings = {
					["\\"] = "close_window",
				},
			},
		},
	},
	config = function()
		require("neo-tree").setup({
			filesystem = {
				filtered_items = {
					visible = true,
					show_hidden_count = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				},
				follow_current_file = {
					enabled = true,
					leave_dirs_open = false,
				},
			},
			buffers = { follow_current_file = { enable = true } },
		})

		-- Custom smart quit command
		vim.api.nvim_create_user_command("SmartQuit", function()
			local buf_count = #vim.fn.getbufinfo({ buflisted = 1 })
			if buf_count == 1 then
				vim.cmd("qall")
			else
				vim.cmd("bdelete")
			end
		end, {})
		-- Map :q to :SmartQuit
		vim.api.nvim_set_keymap("n", ":q", ":SmartQuit<CR>", { noremap = true, silent = true })
	end,
}
