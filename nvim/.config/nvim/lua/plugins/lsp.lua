return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
      'j-hui/fidget.nvim',
      'ray-x/lsp_signature.nvim',
      'b0o/SchemaStore.nvim',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('blink.cmp').get_lsp_capabilities()
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
          settings = {
            typescript = {
              format = {
                semicolons = "remove",
                preferSingleQuotes = true,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
                insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
                insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = false,
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
          },
        },
        yamlls = {
          settings = {
            yaml = {
              schemaStore = { enable = false },
              schemas = {
                ["https://raw.githubusercontent.com/aws/serverless-application-model/main/samtranslator/schema/schema.json"] = {
                  "serverless.yml", "*serverless*.yml", "*serverless*.yaml"
                }
              },
              format = { enable = true, singleQuote = true },
              validate = true,
              completion = true,
              hover = true,
            }
          }
        },
        html = {
          filetypes = { 'html', 'twig', 'hbs' },
        }
      }

      local on_attach = function(client, bufnr)
        local nmap = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
        end

        require("lsp_signature").on_attach({
          bind = true,
          handler_opts = { border = "rounded" },
          hint_enable = false,
          doc_lines = 0,
          signature = {
            show_paramname = true,
            show_annotation = false,
            show_paramdesc = false,
          }
        }, bufnr)

        -- LSP Navigation using Snacks picker
        nmap('gd', function() Snacks.picker.lsp_definitions() end, '[G]oto [D]efinition')
        nmap('gr', function() Snacks.picker.lsp_references() end, '[G]oto [R]eferences')
        nmap('gI', function() Snacks.picker.lsp_implementations() end, '[G]oto [I]mplementation')
        nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
        nmap('<leader>D', function() Snacks.picker.lsp_type_definitions() end, 'Type [D]efinition')
        nmap('<leader>ds', function() Snacks.picker.lsp_symbols() end, '[D]ocument [S]ymbols')
        nmap('<leader>ws', function() Snacks.picker.lsp_workspace_symbols() end, '[W]orkspace [S]ymbols')
        
        -- LSP Actions
        nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
        nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
        nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Help')
        nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, 'Add Workspace')
        nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, 'Remove Workspace')
        nmap('<leader>wl', function()
          print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, 'List Workspaces')

        vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
          vim.lsp.buf.format()
        end, { desc = 'Format current buffer with LSP' })

        -- Document highlighting
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = bufnr,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = bufnr,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- Inlay hints toggle
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          nmap('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr })
          end, '[T]oggle Inlay [H]ints')
        end
      end

      require('mason').setup()
      require('mason-lspconfig').setup({
        ensure_installed = vim.tbl_keys(servers)
      })
      require('fidget').setup()

      for server, config in pairs(servers) do
        config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
        config.on_attach = on_attach
        lspconfig[server].setup(config)
      end

      -- Auto-format on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function()
          if #vim.lsp.get_active_clients({ bufnr = 0 }) > 0 then
            vim.lsp.buf.format({ timeout_ms = 1000 })
          end
        end,
      })

      -- Organize imports on save
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
              elseif r.command then
                vim.lsp.buf.execute_command(r.command)
              end
            end
          end
        end
      })

      -- Custom diagnostic signs
      local signs = {
        Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = "󰋽 "
      }
      for type, icon in pairs(signs) do
        vim.fn.sign_define("DiagnosticSign" .. type, { text = icon, texthl = "DiagnosticSign" .. type })
      end

      -- Diagnostic config
      vim.diagnostic.config({
        virtual_text = {
          prefix = '●',
          spacing = 4,
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = 'if_many',
          style = "minimal",
          focusable = true,
          prefix = function(diagnostic, i, total)
            local icons = {
              [vim.diagnostic.severity.ERROR] = "󰅚",
              [vim.diagnostic.severity.WARN] = "󰀪",
              [vim.diagnostic.severity.INFO] = "󰋽",
              [vim.diagnostic.severity.HINT] = "󰌶",
            }
            local icon = icons[diagnostic.severity] or ""
            return string.format("%s %s [%d/%d]", icon, diagnostic.source or "", i, total) .. "\n"
          end,
          format = function(diagnostic)
            return "    " .. diagnostic.message:gsub("\n", "\n    ")
          end,
        }
      })
    end
  }
}