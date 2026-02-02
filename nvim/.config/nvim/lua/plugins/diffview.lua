return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewFileHistory",
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    {
      "<leader>gV",
      function()
        local lib = require("diffview.lib")
        if lib.get_current_view() then
          vim.cmd("DiffviewClose")
        else
          vim.cmd("DiffviewOpen")
        end
      end,
      desc = "Diffview (toggle)",
    },
    {
      "<leader>gh",
      function()
        require("diffview").file_history()
      end,
      desc = "Diffview: file history",
    },
    {
      "<leader>gH",
      function()
        require("diffview").file_history(nil, { all = true })
      end,
      desc = "Diffview: repository history",
    },
    {
      "<leader>gx",
      "<cmd>DiffviewClose<cr>",
      desc = "Diffview: close view",
    },
  },
  opts = function()
    local actions = require("diffview.actions")

    return {
      enhanced_diff_hl = true,
      use_icons = true,
      view = {
        default = { layout = "diff2_horizontal" },
        merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 36 },
      },
      file_history_panel = {
        log_options = {
          git = {
            single_file = { diff_merges = "combined" },
            multi_file = { diff_merges = "first-parent" },
          },
        },
      },
      keymaps = {
        view = {
          { "n", "<leader>e", actions.toggle_files, { desc = "Toggle file panel" } },
          { "n", "<leader>o", actions.focus_files, { desc = "Focus file panel" } },
          { "n", "[c", actions.prev_conflict, { desc = "Prev conflict" } },
          { "n", "]c", actions.next_conflict, { desc = "Next conflict" } },
          { "n", "co", actions.conflict_choose("ours"), { desc = "Pick ours" } },
          { "n", "ct", actions.conflict_choose("theirs"), { desc = "Pick theirs" } },
          { "n", "cb", actions.conflict_choose("base"), { desc = "Pick base" } },
          { "n", "ca", actions.conflict_choose("all"), { desc = "Pick all" } },
        },
        file_panel = {
          { "n", "q", actions.close, { desc = "Quit Diffview" } },
          { "n", "gf", actions.goto_file, { desc = "Open file" } },
          { "n", "s", actions.toggle_stage_entry, { desc = "Stage / unstage entry" } },
          { "n", "cc", actions.listing_style, { desc = "Cycle list/tree" } },
          { "n", "<leader>e", actions.toggle_files, { desc = "Toggle file panel" } },
        },
        file_history_panel = {
          { "n", "q", actions.close, { desc = "Quit Diffview" } },
          { "n", "gf", actions.goto_file, { desc = "Open file" } },
          { "n", "y", actions.copy_hash, { desc = "Copy commit hash" } },
          { "n", "L", actions.open_commit_log, { desc = "Open commit log" } },
        },
      },
    }
  end,
}
