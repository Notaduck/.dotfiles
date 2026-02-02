vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go" },
  callback = function(args)
    local lsp = require("core.lsp")
    local fname = vim.api.nvim_buf_get_name(args.buf or 0)
    lsp.setup_lsp({
      name = "gopls",
      cmd = { "gopls" },
      root_dir = lsp.resolve_root({
        path = fname,
        patterns = { "go.mod", ".git" },
      }),
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
            shadow = true,
          },
          staticcheck = true,
          gofumpt = true,
          hints = {
            parameterNames = true,
            functionTypeParameters = true,
            constantValues = true,
            rangeVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            assignVariableTypes = true,
          },
        },
      },
    })
  end,
})
