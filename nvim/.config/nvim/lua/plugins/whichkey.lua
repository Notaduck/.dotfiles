return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy", -- loads which-key on demand
    config = function()
      require("which-key").setup({
        -- add config here if you want (or just leave empty for default)
      })
    end,
  }
}
