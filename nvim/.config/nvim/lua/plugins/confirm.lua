return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- JavaScript/TypeScript
        javascript = { "prettier", "prettierd" },
        javascriptreact = { "prettier", "prettierd" },
        typescript = { "prettier", "prettierd" },
        typescriptreact = { "prettier", "prettierd" },

        -- Add Lua formatting
        lua = { "stylua" },

        -- Python
        python = { "isort", "black" },

        -- Go
        go = { "gofmt", "goimports" },

        -- YAML
        yaml = { "yamlfmt" },

        -- JSON
        json = { "jq" },
        jsonc = { "jq" },

        -- Docker
        dockerfile = { "hadolint" },
      },
      -- This is the new way to stop after the first successful formatter
      format_on_save = {
        timeout_ms = 3000,   -- Increased timeout
        lsp_fallback = true,
        stop_after_first = true, -- Stop after first successful formatter
      },
      -- Fix eslint_d issues by adding a notify callback
      notify_on_error = function(err)
        -- Only show errors when not related to eslint_d JSON parsing
        if not err:match("eslint_d: SyntaxError: Unexpected token") then
          vim.notify("Formatting error: " .. err, vim.log.levels.ERROR)
        end
      end,
    },
    config = function(_, opts)
      local conform = require("conform")

      -- Add formatter configurations
      conform.setup(opts)

      -- Add key mappings for manual formatting
      vim.keymap.set({ "n", "v" }, "<leader>fm", function()
        conform.format({
          timeout_ms = 3000,
          lsp_fallback = true,
          stop_after_first = true, -- Also stop after first successful formatter when using the mapping
        })
      end, {
        desc = "Format file or range",
      })
    end,
  },
}
