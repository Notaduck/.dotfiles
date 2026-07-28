return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	build = "make",
	opts = {
		-- Claude Code CLI via ACP — no ANTHROPIC_API_KEY required as long as
		-- you're logged in to the `claude` CLI. Each entry pins a model via
		-- ANTHROPIC_MODEL; switch with `:AvanteSwitchProvider <name>`.
		provider = "claude-code",
		acp_providers = (function()
			local base = function(model)
				return {
					command = "claude-agent-acp",
					args = {},
					env = {
						NODE_NO_WARNINGS = "1",
						ACP_PATH_TO_CLAUDE_CODE_EXECUTABLE = vim.fn.exepath("claude"),
						ACP_PERMISSION_MODE = "bypassPermissions",
						ANTHROPIC_MODEL = model,
					},
				}
			end
			return {
				["claude-code"] = base(nil), -- uses CLI default / ~/.claude/settings.json
				["claude-code-opus-4-7-1m"] = base("claude-opus-4-7[1m]"),
				["claude-code-opus-4-7"] = base("claude-opus-4-7"),
				["claude-code-sonnet-4-6"] = base("claude-sonnet-4-6"),
				["claude-code-haiku-4-5"] = base("claude-haiku-4-5"),
			}
		end)(),
		-- Fallback HTTP provider if you ever want to switch with :AvanteSwitchProvider claude
		providers = {
			claude = {
				endpoint = "https://api.anthropic.com",
				model = "claude-sonnet-4-5-20250929",
				extra_request_body = {
					temperature = 0,
					max_tokens = 8192,
				},
			},
		},
		behaviour = {
			auto_suggestions = false,
			auto_set_highlight_group = true,
			auto_set_keymaps = true,
			auto_apply_diff_after_generation = false,
			support_paste_from_clipboard = true,
		},
		mappings = {
			ask = "<leader>aa",
			edit = "<leader>ae",
			refresh = "<leader>ar",
			focus = "<leader>af",
			toggle = {
				default = "<leader>at",
				debug = "<leader>ad",
				hint = "<leader>ah",
				suggestion = "<leader>as",
				repomap = "<leader>aR",
			},
			diff = {
				ours = "co",
				theirs = "ct",
				all_theirs = "ca",
				both = "cb",
				cursor = "cc",
				next = "]x",
				prev = "[x",
			},
			submit = {
				normal = "<CR>",
				insert = "<C-s>",
			},
			sidebar = {
				apply_all = "A",
				apply_cursor = "a",
				switch_windows = "<Tab>",
				reverse_switch_windows = "<S-Tab>",
			},
		},
		windows = {
			width = 35,
			sidebar_header = {
				align = "center",
				rounded = true,
			},
		},
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"echasnovski/mini.icons",
		"nvim-tree/nvim-web-devicons",
		{
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = { insert_mode = true },
					use_absolute_path = true,
				},
			},
		},
		{
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
