return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "typescript", "javascript", "json", "markdown", "tsx" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}
