vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true

    local lsp = require("core.lsp")

    local schemas = {}
    local ok, schemastore = pcall(require, "schemastore")
    if ok then
      schemas = schemastore.json.schemas()
    end

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    lsp.setup_lsp({
      name = "jsonls",
      cmd = { "vscode-json-language-server", "--stdio" },
      init_options = { provideFormatter = true },
      root_dir = vim.fs.dirname(vim.fs.find({ ".git", "package.json" }, { upward = true })[1] or ""),
      settings = {
        json = {
          validate = { enable = true },
          format = { enable = true },
          schemas = schemas,
          schemaStore = {
            enable = false,
            url = "https://www.schemastore.org/api/json/catalog.json",
          },
        },
        -- 👇 This is the magic bit jsonls actually respects
        ["json.format.enable"] = true,
        ["editor.tabSize"] = 4,
        ["editor.insertSpaces"] = true,
      },
      capabilities = capabilities,
      single_file_support = true,
    })
  end,
})
