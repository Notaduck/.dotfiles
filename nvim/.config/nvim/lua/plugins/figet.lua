return {
  "j-hui/fidget.nvim",
  tag = "legacy", -- Use legacy branch for Neovim < 0.10
  event = "LspAttach",
  opts = {
    -- Default options
    text = {
      spinner = "pipe", -- Use a more minimal spinner
      done = "✓", -- Checkmark for completed tasks
      commenced = "Started", -- Message shown when task starts
      completed = "Completed", -- Message shown when task completes
    },
    align = {
      bottom = true, -- Position at the bottom right
      right = true,
    },
    window = {
      relative = "editor", -- Position relative to the editor
      blend = 10,       -- Slight transparency
      zindex = 10,      -- Display above other windows
      border = "none",  -- No border
      row = 1,          -- Adds bottom margin
      col = 2,          -- Adds left margin
    },
    timer = {
      spinner_rate = 125, -- Faster spinner
      fidget_decay = 2000, -- Show for 2 seconds
      task_decay = 1000, -- Remove completed tasks after 1 second
    },
    fmt = {
      max_width = 60, -- Limit width to avoid cluttering
      fidget = function(fidget_name, spinner)
        return string.format("%s %s", spinner, fidget_name)
      end,
    },
  },
}
