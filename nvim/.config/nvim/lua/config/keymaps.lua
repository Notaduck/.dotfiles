vim.g.mapleader = " "

local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.register({
    c = {
      name = "+code",
      a = { "Code Action" },
      r = { "Rename Symbol" },
      f = { "Format Buffer" },
      d = { "Goto Definition" },
    },
  }, { prefix = "<leader>" })
end

-- Define the mappings so which-key shows them AND they work!
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename Symbol" })
vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format Buffer" })
vim.keymap.set("n", "<leader>cd", vim.lsp.buf.definition, { desc = "Goto Definition" })

