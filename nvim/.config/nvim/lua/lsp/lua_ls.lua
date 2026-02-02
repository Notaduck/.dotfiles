vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua" },
  callback = function(args)
    local lsp = require("core.lsp")
    local fname = vim.api.nvim_buf_get_name(args.buf or 0)
    lsp.setup_lsp({
      name = "lua_ls",
      cmd = { "lua-language-server" },
      root_dir = lsp.resolve_root({
        path = fname,
        patterns = { ".git", "init.lua" },
      }),
      settings = {
        Lua = {
          runtime = {
            version = "LuaJIT",
          },
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
            checkThirdParty = false,
          },
          telemetry = {
            enable = false,
          },
          hint = {
            enable = true,
            paramName = "Literal",
            paramType = true,
            setType = true,
          },
        },
      },
    })
  end,
})
