return {
    'echasnovski/mini.nvim',
    version = false,
    event = 'InsertEnter',
    config = function()
        -- Commenting (gc) is built into Neovim; only autopairs is used from mini.
        require('mini.pairs').setup()
    end
}
