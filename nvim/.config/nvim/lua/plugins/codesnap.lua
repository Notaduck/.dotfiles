return {
  "mistricky/codesnap.nvim",
  cmd = { "CodeSnap", "CodeSnapSave", "CodeSnapSaveToClipboard" },
  lazy = true,
  build = "make",
  opts = {
    has_breadcrumbs = true,
    watermark = "",

    bg_color = "#aab2bd",
    bg_padding = 0,
  },
}
