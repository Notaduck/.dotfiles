return {
  "ravitemer/mcphub.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  build = "npm install -g mcp-hub@latest",
  config = function()
    require("mcphub").setup({
      extensions = {
        avante = {
          make_slash_commands = true, -- adds Avante-aware slash commands
        },
      },
    })
  end,
}
