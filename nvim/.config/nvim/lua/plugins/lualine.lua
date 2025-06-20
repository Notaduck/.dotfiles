-- stylua: ignore
local colors = {
  blue = '#286983',
  cyan = '#56949f',
  black = '#faf4ed',
  white = '#6e6a86',
  red = '#b4637a',
  violet = '#907aa9',
  grey = '#d9d7e0'
}

local bubbles_theme = {
  normal = {
    a = {
      fg = colors.black,
      bg = colors.violet,
    },
    b = {
      fg = colors.white,  -- Actually #6e6a86 (darker color)
      bg = colors.grey,   -- #d9d7e0 (light grey)
    },
    c = {
      fg = colors.white,
    },
  },

  insert = {
    a = {
      fg = colors.black,
      bg = colors.blue,
    },
  },
  visual = {
    a = {
      fg = colors.black,
      bg = colors.cyan,
    },
  },
  replace = {
    a = {
      fg = colors.black,
      bg = colors.red,
    },
  },

  inactive = {
    a = {
      fg = colors.white,
      bg = colors.black,
    },
    b = {
      fg = colors.white,
      bg = colors.black,
    },
    c = {
      fg = colors.white,
    },
  },
}
return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "rose-pine/neovim" },
  config = function()
    -- Bubbles config for lualine
    -- Author: lokesh-krishna

    -- MIT license, see LICENSE for more details.

    -- Create LSP status function
    local function lsp_status()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      if #clients == 0 then
        return ""
      end

      local client_names = {}
      for _, client in ipairs(clients) do
        table.insert(client_names, client.name)
      end

      return " " .. table.concat(client_names, ", ")
    end

    require("lualine").setup({
      options = {
        -- theme =
        theme = bubbles_theme,
        component_separators = "",
        section_separators = {
          left = "",
          right = "",
        },
      },
      sections = {
        lualine_a = {
          {
            "mode",
            separator = {
              left = "",
            },
            right_padding = 2,
          },
        },
        lualine_b = { "filename", "branch" },
        lualine_c = { "%=", "filename" },
        lualine_x = { lsp_status }, -- Add LSP status here
        lualine_y = { "filetype", "progress" },
        lualine_z = {
          {
            "location",
            separator = {
              right = "",
            },
            left_padding = 2,
          },
        },
      },
      inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
      tabline = {},
      extensions = {},
    })
  end,
}
