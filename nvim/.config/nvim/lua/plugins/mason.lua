return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { {
      "<leader>cm",
      "<cmd>Mason<cr>",
      desc = "Mason",
    } },
    opts = {
      ensure_installed = { -- LSP Servers
        "lua-language-server",
        "pyright",
        "gopls",
        "typescript-language-server",
        "yaml-language-server",
        "json-lsp",
        "docker-compose-language-service",
        "dockerfile-language-server", -- Formatters
        "stylua",
        "isort",
        "black",
        "goimports",
        "yamlfmt",
        "prettier",
        "jq",
        "hadolint",
        "gh-actions-language-server",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)

      -- Install listed servers, formatters and linters
      local mr = require("mason-registry")
      local function ensure_installed()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end

      if mr.refresh then
        mr.refresh(ensure_installed)
      else
        ensure_installed()
      end

      -- Add status info command
      vim.api.nvim_create_user_command("ToolStatus", function()
        local installed = {}
        local missing = {}

        for _, tool in ipairs(opts.ensure_installed) do
          if mr.is_installed(tool) then
            table.insert(installed, tool)
          else
            table.insert(missing, tool)
          end
        end

        -- Create a pretty report
        local lines = { "# Dev Tool Status" }

        if #installed > 0 then
          table.insert(lines, "\n## Installed Tools ✅")
          for _, tool in ipairs(installed) do
            table.insert(lines, "- " .. tool)
          end
        end

        if #missing > 0 then
          table.insert(lines, "\n## Missing Tools ❌")
          for _, tool in ipairs(missing) do
            table.insert(lines, "- " .. tool)
          end
          table.insert(lines, "\nRun :MasonInstallAll to install missing tools")
        else
          table.insert(lines, "\nAll required tools are installed! 🎉")
        end

        -- Show in a floating window
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
        vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

        local width = math.min(60, vim.o.columns - 4)
        local height = math.min(#lines + 2, vim.o.lines - 4)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local opts = {
          relative = "editor",
          width = width,
          height = height,
          row = row,
          col = col,
          style = "minimal",
          border = "rounded",
        }

        local win = vim.api.nvim_open_win(buf, true, opts)
        vim.api.nvim_win_set_option(win, "conceallevel", 2)
        vim.api.nvim_win_set_option(win, "foldenable", false)

        -- Close with q or ESC
        vim.keymap.set("n", "q", "<cmd>close<CR>", {
          buffer = buf,
          nowait = true,
        })
        vim.keymap.set("n", "<ESC>", "<cmd>close<CR>", {
          buffer = buf,
          nowait = true,
        })
      end, {})

      -- Add a command to install all tools
      vim.api.nvim_create_user_command("MasonInstallAll", function()
        vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
      end, {})
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      automatic_installation = true,
      ensure_installed = nil, -- Use the list from mason.nvim
    },
  },
}
