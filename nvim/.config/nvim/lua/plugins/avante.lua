return {
  'yetone/avante.nvim',
  event = 'VeryLazy',
  lazy = true,
  version = '*', -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  opts = {
    provider = 'copilot',
    copilot = {
      model = 'claude-3.7-sonnet', -- Best balance of quality and speed
      -- Other models you might want to try:
      -- model = 'claude-3.5-sonnet', -- Faster, but less capable
      -- model = 'claude-3-haiku',    -- Even faster but less capable
      -- model = 'gpt-4o',          -- OpenAI alternative
      temperature = 0,        -- 0 for deterministic responses
      max_tokens = 8192,      -- High token limit for longer responses
      timeout = 60000,        -- 60 seconds timeout for network operations
      proxy = nil,            -- Set to your proxy URL if needed
      allow_insecure = false, -- Set to true only if you need to bypass SSL verification
      -- disable_tools = {
      --   'rag_search',
      --   'python',
      --   'create_file',
      --   'rename_file',
      --   'delete_file',
      --   'create_dir',
      --   'rename_dir',
      --   'delete_dir',
      -- }, -- Enable function calling capabilities
      code_editing_commands = true, -- Enable code editing commands
      telemetry = false,            -- Disable telemetry for privacy
      split_threshold = 1024,       -- Split large messages at this character count
    },


    -- add any opts here
    -- for example
    -- provider = 'openai',
    -- openai = {
    --   endpoint = 'https://api.openai.com/v1',
    --   model = 'gpt-4o', -- your desired model (or use gpt-4o, etc.)
    --   timeout = 30000, -- timeout in milliseconds
    --   temperature = 0, -- adjust if needed
    --   max_tokens = 4096,
    --   -- reasoning_effort = "high" -- only supported for reasoning models (o1, etc.)
    -- },
    windows = {
      ---@type "right" | "left" | "top" | "bottom"
      position = 'left',  -- the position of the sidebar
      wrap = true,        -- similar to vim.o.wrap
      width = 30,         -- default % based on available width
      sidebar_header = {
        enabled = true,   -- true, false to enable/disable the header
        align = 'center', -- left, center, right for title
        rounded = true,
      },
      input = {
        prefix = '> ',
        height = 8, -- Height of the input window in vertical layout
      },
      edit = {
        border = 'rounded',
        start_insert = true, -- Start insert mode when opening the edit window
      },
      ask = {
        floating = false,    -- Open the 'AvanteAsk' prompt in a floating window
        start_insert = true, -- Start insert mode when opening the ask window
        border = 'rounded',
        ---@type "ours" | "theirs"
        focus_on_apply = 'ours', -- which diff to focus after applying
      },
    },
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = 'make',
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'stevearc/dressing.nvim',
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    --- The below dependencies are optional,
    'echasnovski/mini.pick',         -- for file_selector provider mini.pick
    'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
    'hrsh7th/nvim-cmp',              -- autocompletion for avante commands and mentions
    'ibhagwan/fzf-lua',              -- for file_selector provider fzf
    'nvim-tree/nvim-web-devicons',   -- or echasnovski/mini.icons
    'zbirenbaum/copilot.lua',        -- for providers='copilot'
    {
      -- support for image pasting
      'HakonHarnes/img-clip.nvim',
      event = 'VeryLazy',
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { 'markdown', 'Avante' },
      },
      ft = { 'markdown', 'Avante' },
    },
  },
}
