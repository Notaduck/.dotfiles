return {
  "mistricky/codesnap.nvim",
  tag = "v2.0.0",
  cmd = { "CodeSnap", "CodeSnapSave", "CodeSnapASCII", "CodeSnapHighlight" },
  lazy = true,
  opts = {
    show_line_number = true,
    snapshot_config = {
      code_config = {
        breadcrumbs = {
          enable = true,
        },
      },
      watermark = {
        content = "",  -- Empty watermark
      },
      background = "#aab2bd",  -- Solid color background
    },
  },
}
