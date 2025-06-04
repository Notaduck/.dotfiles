return {
  { "L3MON4D3/LuaSnip", keys = {} },
  {
    "saghen/blink.cmp",
    dependencies = {
      "rafamadriz/friendly-snippets",
      'Kaiser-Yang/blink-cmp-avante',
      "onsails/lspkind.nvim",
    },
    version = "*",
    config = function()
      require("blink.cmp").setup({
        snippets = { preset = "luasnip" },
        -- signature = { enabled = true },
        -- signature = {
        --   enabled = true,
        --   window = { border = "rounded" },
        -- },
        appearance = {
          use_nvim_cmp_as_default = false,
          -- nerd_font_variant = "normal",
          nerd_font_variant = "mono",
        },
        sources = {
          default = { "avante", "lsp", "path", "snippets", "buffer" },
          providers = {
            cmdline = {
              min_keyword_length = 2,
            },
            avante = {
              module = 'blink-cmp-avante',
              name = 'Avante',
              opts = {
                -- options for blink-cmp-avante
              }
            }
          },
        },
        keymap = {
          ["<C-f>"] = {},
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = {
            function(cmp)
              return cmp.select_next()
            end,
            "snippet_forward",
            "fallback",
          },
          ["<S-Tab>"] = {
            function(cmp)
              return cmp.select_prev()
            end,
            "snippet_backward",
            "fallback",
          },

          ["<Up>"] = { "select_prev", "fallback" },
          ["<Down>"] = { "select_next", "fallback" },
        },
        cmdline = {
          enabled = false,
          completion = { menu = { auto_show = true } },
          keymap = {
            ["<CR>"] = { "accept_and_enter", "fallback" },
          },
        },
        completion = {
          menu = {
            border = "single",
            scrolloff = 1,
            scrollbar = false,
            winhighlight =
            'Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
            draw = {
              padding = 4,
              columns = {
                { "label" },
                { "kind_icon", "kind" },
                -- { "kind_icon" },
              },
              components = {
                kind_icon = {
                  text = function(item)
                    local kind = require("lspkind").symbol_map[item.kind] or ""
                    return kind .. " "
                  end,
                  highlight = "CmpItemKind",
                },
              }
            },
          },
          documentation = {
            window = {
              border = "single",
              scrollbar = false,
              winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc',
            },
            auto_show = true,
            auto_show_delay_ms = 500,
          },
        },
      })

      -- Load global snippets from friendly-snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Load project-specific snippets from .vscode folder if it exists
      local project_snippets = vim.fn.getcwd() .. "/.vscode"
      if vim.fn.isdirectory(project_snippets) == 1 then
        require("luasnip.loaders.from_vscode").lazy_load({ paths = { project_snippets } })
      end
    end,
  },
}
