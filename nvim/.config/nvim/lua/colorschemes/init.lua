-- This file loads all colorscheme plugins but doesn't set any of them
-- Scan the colorschemes directory for all .lua files
local colorschemes = {}
local colorschemes_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""

-- Skip loading this init.lua file itself
for _, file in ipairs(vim.fn.readdir(colorschemes_dir, [[v:val =~ '\.lua$' && v:val != 'init.lua']])) do
    -- Extract the name without .lua extension
    local scheme_name = file:gsub("%.lua$", "")
    -- Load the colorscheme spec and add it to our list
    table.insert(colorschemes, require("colorschemes." .. scheme_name))
end

return colorschemes
