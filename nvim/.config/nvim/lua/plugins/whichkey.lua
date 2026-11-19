return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy", -- loads which-key on demand
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>r", group = "run/eval" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "toggle" },
        { "<leader>u", group = "ui" },
        { "<leader>x", group = "trouble" },
      },
    },
  }
}
