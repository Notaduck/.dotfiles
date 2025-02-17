return {
	"nvim-neo-tree/neo-tree.nvim",
	tag = "3.6",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		local neotree = require("neo-tree")
		local do_setcd = function(state)
			local p = state.tree:get_node().path
			print(p) -- show in command line
			vim.cmd(string.format('exec(":lcd %s")', p))
		end
		neotree.setup({
			hide_root_node = true,
			retain_hidden_root_indent = false,
			enable_git_status = false,
			enable_modified_markers = false,
			use_popups_for_input = false, -- not floats for input
			commands = {
				setcd = function(state)
					do_setcd(state)
				end,
				find_files = function(state)
					do_setcd(state)
					require("telescope.builtin").find_files()
				end,
				grep = function(state)
					do_setcd(state)
					require("telescope.builtin").live_grep()
				end,
			},
			window = {
				--c(d), z(p)
				mappings = {
					["o"] = "open",
					["x"] = "close_node",
					["u"] = "navigate_up",
					["I"] = "toggle_hidden",
					["C"] = "set_root",
					["r"] = "refresh",
					["c"] = "setcd",
					["p"] = "find_files",
					["g"] = "grep",
					["<c-a>"] = {
						"add",
						config = {
							show_path = "relative",
						},
					},
					["<c-d>"] = "delete",
					["<c-m>"] = {
						"move",
						config = {
							show_path = "relative",
						},
					},
					["<c-c>"] = {
						"copy",
						config = {
							show_path = "relative",
						},
					},
					["d"] = function() end,
					["m"] = function() end,
					["a"] = function() end,
					["z"] = function() end,
				},
			},
			filesystem = {
				filtered_items = {
					show_hidden_count = false,
				},
				components = {
					-- hide file icon
					icon = function(config, node, state)
						if node.type == "file" then
							return {
								text = "",
								highlight = config.highlight,
							}
						end
						return require("neo-tree.sources.common.components").icon(config, node,
							state)
					end,
				}, -- components
			}, -- filesystem
			event_handlers = {
				{
					event = "neo_tree_buffer_enter",
					handler = function(arg)
						vim.cmd([[
              setlocal relativenumber
            ]])
					end,
				},
			},
		})
		-- set keymaps
		local keymap = vim.keymap -- for conciseness
		keymap.set("n", "<leader>e", "<cmd>Neotree toggle filesystem right<cr>")
		keymap.set("n", "<space>e", "<cmd>Neotree filesystem reveal right<cr>")
	end,
}
-- EOP
