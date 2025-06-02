return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      integrations = {
        gitsigns = true,
        nvimtree = true,
        telescope = true,
        which_key = true,
        indent_blankline = {
          enabled = true,
        },
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
      },
      custom_highlights = {
        DiagnosticVirtualTextError = { fg = "#ed8796", bg = "#362c3d" },
        DiagnosticVirtualTextWarn = { fg = "#eed49f", bg = "#35344b" },
        DiagnosticVirtualTextInfo = { fg = "#8aadf4", bg = "#2d3352" },
        DiagnosticVirtualTextHint = { fg = "#a6da95", bg = "#2d353b" },
      },
    })
  end,
}
