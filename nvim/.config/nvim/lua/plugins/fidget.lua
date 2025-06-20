return {
    "j-hui/fidget.nvim",
    tag = "legacy", -- Use legacy branch for Neovim < 0.10
    event = "LspAttach",
    opts = {
        -- Default options
        text = {
            spinner = "arc", -- Try a different spinner
            done = "✔", -- Checkmark for completed tasks
            commenced = "Started", -- Message shown when task starts
            completed = "Completed" -- Message shown when task completes
        },
        align = {
            bottom = true, -- Move to top
            right = true -- Move to left
        },
        window = {
            relative = "editor", -- Position relative to the editor
            blend = 0, -- Slight transparency
            zindex = 50, -- Display above other windows
            -- border = "rounded", -- Add a rounded border for aesthetics
            row = 2, -- Add top margin
            col = 4 -- Add left margin
        },
        timer = {
            spinner_rate = 100, -- Faster spinner
            fidget_decay = 1000, -- Show for 2 seconds
            task_decay = 1000 -- Remove completed tasks after 1 second
        },
        view = {
            stack_upwards = true, -- Display notification items from bottom to top
            icon_separator = " ", -- Separator between group name and icon
            group_separator = "---", -- Separator between notification groups
            group_separator_hl = -- Highlight group used for group separator
            "Comment",
            render_message = -- How to render notification messages
            function(msg, cnt)
                return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
            end
        },
        ignore = {"null-ls"}, -- Hide null-ls tasks if you use it
        fmt = {
            -- max_width = 60, -- Limit width to avoid cluttering
            fidget = function(fidget_name, spinner)
                return string.format(" %s %s", spinner, fidget_name)
            end
        }
    }
}
