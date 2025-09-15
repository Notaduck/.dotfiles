-- YAML LSP configuration
-- Requirements:
--   1. Install yaml-language-server (npm i -g yaml-language-server)
--   2. Optional: install schemastore.nvim plugin for rich schema support: b0o/schemastore.nvim
-- This sets up yamlls with schemastore schemas (if available) and sensible defaults.
-- Skips docker-compose* files so docker_compose_language_service (docker.lua) can attach.

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  pattern = { "yaml", "yml" },
  callback = function()
    local filename = vim.fn.expand("%:t")
    if filename:match("docker%-compose") or filename:match("docker%.") then
      return
    end

    local lsp = require("core.lsp")

    local schemas = {}
    local ok, schemastore = pcall(require, "schemastore")
    if ok then
      schemas = schemastore.yaml.schemas()
    end

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    lsp.setup_lsp({
      name = "yamlls",
      cmd = { "yaml-language-server", "--stdio" },
      root_dir = vim.fs.dirname(
        vim.fs.find({ ".git", "package.json", "helmfile.yaml", "Chart.yaml" }, { upward = true })[1] or ""
      ),
      settings = {
        yaml = {
          validate = true,
          hover = true,
          completion = true,
          format = { enable = true },
          keyOrdering = false,
          schemas = schemas,
          schemaStore = {
            enable = false, -- Use schemastore.nvim instead to avoid network fetch each start
            url = "https://www.schemastore.org/api/json/catalog.json",
          },
        },
      },
      capabilities = capabilities,
      single_file_support = true,
    })
  end,
})
