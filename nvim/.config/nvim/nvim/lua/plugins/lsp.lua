return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'hrsh7th/cmp-nvim-lsp',
      'j-hui/fidget.nvim',
      'ray-x/lsp_signature.nvim',
      'b0o/SchemaStore.nvim',
    },
    config = function()
      -- Setup diagnostic signs with more prominent symbols
      local signs = {
        Error = "󰅚 ", -- Error symbol
        Warn = "󰀪 ", -- Warning symbol
        Hint = "󰌶 ", -- Hint symbol
        Info = "󰋽 ", -- Info symbol
      }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- Define diagnostic icons once to maintain consistency
      local diagnostic_icons = {
        [vim.diagnostic.severity.ERROR] = { icon = "󰅚", label = "Error" },
        [vim.diagnostic.severity.WARN]  = { icon = "󰀪", label = "Warning" },
        [vim.diagnostic.severity.INFO]  = { icon = "󰋽", label = "Info" },
        [vim.diagnostic.severity.HINT]  = { icon = "󰌶", label = "Hint" },
      }

      -- Configure diagnostics display
      vim.diagnostic.config({
        virtual_text = {
          prefix = '●',
          severity = {
            min = vim.diagnostic.severity.HINT,
          },
          spacing = 4,
          format = function(diagnostic)
            local diag = diagnostic_icons[diagnostic.severity]
            return string.format("%s %s", diag and diag.icon or "", diagnostic.message)
          end,
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = 'if_many', -- Only show source when multiple sources exist
          header = '',        -- We'll handle header formatting in prefix
          max_width = 80,     -- Limit width for better readability
          prefix = function(diagnostic, i, total)
            local diag = diagnostic_icons[diagnostic.severity]
            if not diag then return "" end

            -- Build header components
            local header_parts = {
              string.format("%s %s", diag.icon, diag.label),
              diagnostic.source and string.format("(%s)", diagnostic.source) or nil,
              total > 1 and string.format("[%d/%d]", i, total) or nil,
            }

            -- Filter out nil values and join with spaces
            local header = table.concat(vim.tbl_filter(function(v) return v ~= nil end, header_parts), " ")
            return header .. "\n" -- Add newline for cleaner separation
          end,
          format = function(diagnostic)
            -- Add indentation and wrap long messages
            local message = diagnostic.message:gsub("\n", "\n    ") -- Maintain indentation for multiline
            return "    " .. message
          end,
          focus = false,     -- Don't auto-focus the floating window
          focusable = true,  -- But allow focusing if needed
          style = "minimal", -- Clean window style
        },
      })

      local on_attach = function(client, bufnr)
        local nmap = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
        end

        -- Setup signature help for current buffer
        require("lsp_signature").on_attach({
          bind = true,
          handler_opts = {
            border = "rounded"
          },
          hint_enable = false, -- Disable the inline hint with magnifying glass
          max_height = 12,
          max_width = 120,
          floating_window = true,
          toggle_key = nil, -- Can set a toggle key if desired

          -- Minimal display settings for current buffer
          doc_lines = 0,             -- Don't show documentation
          signature = {
            show_annotation = false, -- Don't show return type annotation
            show_paramname = true,   -- Do show parameter names
            show_paramdesc = false,  -- Don't show parameter descriptions
          }
        }, bufnr)

        nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
        nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')
        nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
        nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
        nmap('<leader>wl', function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, '[W]orkspace [L]ist Folders')

        vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
          vim.lsp.buf.format()
        end, { desc = 'Format current buffer with LSP' })
      end

      require('mason').setup()
      require('mason-lspconfig').setup({
        ensure_installed = {
          "yamlls", -- YAML language server for Serverless Framework
          "jsonls", -- JSON language server for better JSON schema support
        }
      })
      require('fidget').setup()

      -- Setup global configuration for lsp_signature
      require('lsp_signature').setup({
        debug = false,
        log_path = vim.fn.stdpath("cache") .. "/lsp_signature.log",
        verbose = false,
        bind = true,
        doc_lines = 0, -- Show no documentation lines
        max_height = 12,
        max_width = 80,
        wrap = true,
        floating_window = true,
        floating_window_above_cur_line = true,
        floating_window_off_x = 1,
        floating_window_off_y = 0,
        close_timeout = 4000,
        fix_pos = false,
        hint_enable = false, -- Disable inline hints with magnifying glass
        handler_opts = {
          border = "rounded"
        },
        prefix = "🐼 ", -- Add panda emoji prefix to signature hint
        always_trigger = false,
        auto_close_after = nil,
        extra_trigger_chars = {},
        zindex = 200,
        padding = '',
        transparency = nil,
        shadow_blend = 37,
        shadow_guibg = 'Black',
        timer_interval = 200,
        toggle_key = nil,
        select_signature_key = nil,
        move_cursor_key = nil,

        -- Settings to simplify the view
        signature_window = true,       -- Show signature in a floating window
        signature_help_by_lsp = false, -- Better param docs from LSP if available
        check_completion_visible = true,
        doc_lines = 0,                 -- Don't show documentation - just the signature
        show_signature_in_preview = false,

        -- For a more minimal view focused only on parameters:
        signature = {
          enabled = true,
          show_label = true,       -- Show parameter names
          show_annotation = false, -- Don't show function return type
          show_paramname = true,   -- Show parameter names in signature
          show_paramdesc = false,  -- Don't show parameter descriptions
          max_height = 10,
          max_width = 60,
        },
      })


      capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              diagnostics = { globals = { 'vim' } },
            },
          },
        },
        jsonls = {
          settings = {
            json = {
              schemas = require('schemastore').json.schemas(),
              validate = { enable = true },
            },
          },
        },
        vtsls = {
          on_attach = on_tsserver_attach,
          settings = {
            -- schema: https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
            typescript = {
              format = {
                semicolons                                                 = "remove",
                preferSingleQuotes                                         = true,
                -- function(x)  vs  function( x )
                insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
                -- array[x]  vs  array[ x ]
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets    = false,
                -- {content}  vs  { content }
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces      = true,
                -- {} vs { }
                insertSpaceAfterOpeningAndBeforeClosingEmptyBraces         = false
              },
              preferences = {
                importModuleSpecifier = "non-relative",
                quoteStyle = "single"
              },
              inlayHints = {
                parameterNames = { enabled = "all" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = true },
                propertyDeclarationTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                enumMemberValues = { enabled = true },
              },
            },
          }
        },

        html = { filetypes = { 'html', 'twig', 'hbs' } },
        yamlls = {
          settings = {
            yaml = {
              schemaStore = {
                enable = false, -- Disable built-in schemaStore as we're using SchemaStore.nvim
              },
              -- schemas = require('schemastore').yaml.schemas(),

              schemas = {
                ["https://raw.githubusercontent.com/aws/serverless-application-model/main/samtranslator/schema/schema.json"] = {
                  "serverless.yml",
                  "*serverless*.yml",
                  "*serverless*.yaml"
                },
                -- Add other specific schemas as needed
                -- You can find more schemas in SchemaStore.nvim or add custom ones
              },
              format = {
                enable = true,
                singleQuote = true
              },
              validate = true,
              completion = true,
              hover = true,
            }
          }
        }
      }

      for server, _ in pairs(servers) do
        require('lspconfig')[server].setup(vim.tbl_deep_extend('force', {
          capabilities = capabilities,
          on_attach = on_attach,
        }, servers[server] or {}))
      end

      -- Add auto-import organization for TypeScript files
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        callback = function()
          local params = vim.lsp.util.make_range_params()
          params.context = { only = { "source.organizeImports" } }

          local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
          for _, res in pairs(result or {}) do
            for _, r in pairs(res.result or {}) do
              if r.edit then
                vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
              else
                vim.lsp.buf.execute_command(r.command)
              end
            end
          end
        end
      })

      -- Format on save for files with LSP attached
      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function()
          -- Check if there are any active language servers for this buffer
          local active_clients = vim.lsp.get_active_clients({ bufnr = 0 })
          if #active_clients > 0 then
            vim.lsp.buf.format({ timeout_ms = 1000 })
          end
        end,
      })
    end,
  },
}
