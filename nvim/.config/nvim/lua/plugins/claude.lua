return {
	"coder/claudecode.nvim",
	dependencies = { "folke/snacks.nvim" },
	config = true,
	-- Keymaps disabled to avoid <leader>a* conflicts with avante.nvim.
	-- Commands are still available: :ClaudeCode, :ClaudeCodeFocus,
	-- :ClaudeCodeSelectModel, :ClaudeCodeAdd, :ClaudeCodeSend,
	-- :ClaudeCodeTreeAdd, :ClaudeCodeDiffAccept, :ClaudeCodeDiffDeny.
}
