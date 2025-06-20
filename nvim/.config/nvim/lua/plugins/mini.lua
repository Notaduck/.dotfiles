return {
    'echasnovski/mini.nvim',
    version = false,
    config = function()
        -- Enable mini.comment
        require('mini.comment').setup({
            -- Optional configuration options
            options = {
                -- Whether to ignore blank lines
                ignore_blank_line = false,

                -- Whether to recognize as comments only lines which start with a comment marker
                start_of_line = false,

                -- Whether to ensure single space pad for comment parts
                pad_comment_parts = true
            },

            -- Hook functions to be executed at certain stages of commenting
            hooks = {
                -- Before successful commenting
                pre = function()
                end,
                -- After successful commenting
                post = function()
                end
            }
        })

        -- Enable mini.pairs
        require('mini.pairs').setup({
            -- In which modes mappings are created
            modes = {
                insert = true,
                command = false,
                terminal = false
            },

            -- Global mappings. Each right hand side should be a pair information, a
            -- table with at least these fields (see more in |MiniPairs.map|):
            -- - action: one of 'open', 'close', 'closeopen'.
            -- - pair: two-character string for pair to be used.
            -- By default pair is not inserted after 'autopairs-disable' command.
            mappings = {
                ['('] = {
                    action = 'open',
                    pair = '()',
                    neigh_pattern = '[^\\].'
                },
                ['['] = {
                    action = 'open',
                    pair = '[]',
                    neigh_pattern = '[^\\].'
                },
                ['{'] = {
                    action = 'open',
                    pair = '{}',
                    neigh_pattern = '[^\\].'
                },

                [')'] = {
                    action = 'close',
                    pair = '()',
                    neigh_pattern = '[^\\].'
                },
                [']'] = {
                    action = 'close',
                    pair = '[]',
                    neigh_pattern = '[^\\].'
                },
                ['}'] = {
                    action = 'close',
                    pair = '{}',
                    neigh_pattern = '[^\\].'
                },

                ['"'] = {
                    action = 'closeopen',
                    pair = '""',
                    neigh_pattern = '[^\\].',
                    register = {
                        cr = false
                    }
                },
                ["'"] = {
                    action = 'closeopen',
                    pair = "''",
                    neigh_pattern = '[^%a\\].',
                    register = {
                        cr = false
                    }
                },
                ['`'] = {
                    action = 'closeopen',
                    pair = '``',
                    neigh_pattern = '[^\\].',
                    register = {
                        cr = false
                    }
                }
            }
        })

        -- Enable mini.snippets with VS Code snippets support
        local snippets = require('mini.snippets')

        -- Function to read VSCode snippets JSON files
        local function read_vscode_snippets()
            local vscode_snippets = {}
            local snippets_dir = vim.fn.stdpath('config') .. '/snippets'

            -- Create snippets directory if it doesn't exist
            if vim.fn.isdirectory(snippets_dir) == 0 then
                vim.fn.mkdir(snippets_dir, 'p')
            end

            -- Read all JSON files in the snippets directory
            local files = vim.fn.globpath(snippets_dir, '*.json', false, true)
            for _, file in ipairs(files) do
                local content = vim.fn.readfile(file)
                local json_content = table.concat(content, '\n')
                local ok, decoded = pcall(vim.fn.json_decode, json_content)

                if ok and type(decoded) == 'table' then
                    -- VSCode snippet format conversion to mini.snippet format
                    for name, snippet_data in pairs(decoded) do
                        local body = snippet_data.body
                        if type(body) == 'table' then
                            body = table.concat(body, '\n')
                        end

                        -- Convert VSCode-style $1, $2 to mini-style <+1+>, <+2+>
                        body = body:gsub('$(%d+)', function(n)
                            return '<+' .. n .. '+>'
                        end)

                        -- Convert ${1:default} to <+1:default+>
                        body = body:gsub('${(%d+):(.-)}', function(n, default)
                            return '<+' .. n .. ':' .. default .. '+>'
                        end)

                        -- Add to snippets for appropriate filetypes
                        if snippet_data.scope then
                            if not vscode_snippets[snippet_data.scope] then
                                vscode_snippets[snippet_data.scope] = {}
                            end
                            vscode_snippets[snippet_data.scope][name] = body
                        else
                            if not vscode_snippets['_'] then
                                vscode_snippets['_'] = {}
                            end
                            vscode_snippets['_'][name] = body
                        end
                    end
                end
            end

            return vscode_snippets
        end

        -- Define your custom snippets
    end
}
