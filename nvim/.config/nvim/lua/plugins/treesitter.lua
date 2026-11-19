return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      local ts = require("nvim-treesitter")
      local available = ts.get_available()
      ts.install({ "lua", "typescript", "javascript", "json", "markdown", "tsx", "yaml", "regex", "bash" })

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter-attach", { clear = true }),
        callback = function(args)
          local buf = args.buf
          local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
          if not lang or not vim.tbl_contains(available, lang) then
            return
          end
          -- auto-install missing parsers, then enable highlighting + indent
          ts.install(lang):await(function(err)
            if err or not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            if pcall(vim.treesitter.start, buf, lang) then
              vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end)
        end,
      })
    end,
  },
}
