vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python" },
  callback = function(args)
    local lsp = require("core.lsp")
    local fname = vim.api.nvim_buf_get_name(args.buf or 0)
    lsp.setup_lsp({
      name = "pyright",
      cmd = { "pyright-langserver", "--stdio" },
      root_dir = lsp.resolve_root({
        path = fname,
        patterns = { ".git", "pyproject.toml", "setup.py", "requirements.txt" },
      }),
      settings = {
        python = {
          analysis = {
            typeCheckingMode = "basic",
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = "openFilesOnly",
          },
        },
      },
    })
  end,
})
