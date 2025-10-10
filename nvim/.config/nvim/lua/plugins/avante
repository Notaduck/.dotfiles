return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false,
  build = (vim.fn.has("win32") == 1) and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",

  opts = {
    provider = "copilot",
    providers = {
      copilot = {
        endpoint = "https://api.githubcopilot.com",
        api_key_name = "GITHUB_TOKEN",
        timeout = 30000,
        extra_request_body = {
          temperature = 0.2,
          max_tokens = 1024,
        },
      },
    },
    suggestion = {
      enabled = true,
      debounce = 2000,
      delay = 1000,
    },
    input = { provider = "snacks" },
    windows = {
      position = "left",
      width = 40,
      wrap = true,
      sidebar_header = { enabled = true, align = "center", rounded = true },
      input = { prefix = "> ", height = 6 },
      edit = { border = "rounded", start_insert = true },
      ask = { floating = false, start_insert = true, border = "rounded", focus_on_apply = "ours" },
    },
    hints = { enabled = false },
  },

  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "echasnovski/mini.pick",
    "nvim-telescope/telescope.nvim",
    "ibhagwan/fzf-lua",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
    "zbirenbaum/copilot.lua",

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
      "ravitemer/mcphub.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      build = "npm install -g mcp-hub@latest",
      config = function()
        require("mcphub").setup({
          extensions = { avante = { make_slash_commands = true } },
        })
      end,
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = { file_types = { "markdown", "Avante" } },
      ft = { "markdown", "Avante" },
    },
  },
}
