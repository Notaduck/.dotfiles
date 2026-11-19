-- Sole LSP progress UI (noice's lsp.progress is disabled). Sits above the statusline.
return {
    "j-hui/fidget.nvim",
    version = "*",
    event = "LspAttach",
    opts = {
        progress = {
            display = {
                done_icon = "✔",
                done_ttl = 1, -- Remove completed tasks after 1 second
            },
        },
        notification = {
            window = {
                y_padding = 0, -- Rows between the window and the statusline
            },
        },
    },
}
