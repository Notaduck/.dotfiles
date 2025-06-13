return {
  "jellydn/quick-code-runner.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    debug = true,
  },
  cmd = { "QuickCodeRunner", "QuickCodePad" },
  keys = {
    {
      "<leader>co",
      ":QuickCodeRunner<CR>",
      desc = "Quick Code Runner",
      mode = "v",
    },
    {
      "<leader>cp",
      ":QuickCodePad<CR>",
      desc = "Quick Code Pad",
    },
  },
}
