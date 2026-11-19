-- One switch for the editor's colours.
--
-- Themes are palette files in ~/.config/theme/palettes/<name>.conf, shared
-- with the `theme` command. Each carries the Neovim colorscheme name
-- (@thm_nvim), light or dark mode (@thm_mode) and the colours lualine uses.
--
-- The `theme` command writes the active name to ~/.local/state/theme/current
-- and calls `apply()` in every running Neovim over its server socket.
-- core/lazy.lua calls `apply()` once the colorscheme plugins are loaded.
local M = {}

local home = os.getenv("HOME")
local palettes = (os.getenv("XDG_CONFIG_HOME") or home .. "/.config") .. "/theme/palettes"
local state_file = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/theme/current"

M.default = "catppuccin-mocha"

--- Parse a palette file into a table keyed by the @thm_* names, or nil when
--- the file is missing or has no Neovim colorscheme.
function M.palette(name)
	local ok, lines = pcall(vim.fn.readfile, palettes .. "/" .. name .. ".conf")
	if not ok then
		return nil
	end
	local p = {}
	for _, line in ipairs(lines) do
		local key, value = line:match('^set%s+%-g%s+@thm_([%w_]+)%s+"([^"]*)"')
		if key then
			p[key] = value
		end
	end
	return p.nvim and p or nil
end

--- Name of the theme selected by the `theme` command, or the default when the
--- state file is missing or names a theme without a palette.
function M.current()
	local ok, lines = pcall(vim.fn.readfile, state_file)
	local name = ok and lines[1] and vim.trim(lines[1]) or ""
	if name ~= "" and M.palette(name) then
		return name
	end
	return M.default
end

--- Lualine bubbles theme built from a palette (defaults to the current one).
function M.lualine_theme(p)
	p = p or M.palette(M.current())
	if not p then
		return "auto"
	end
	return {
		normal = {
			a = { fg = p.on_accent, bg = p.accent },
			b = { fg = p.subtle, bg = p.surface },
			c = { fg = p.subtle },
		},
		insert = { a = { fg = p.on_accent, bg = p.insert } },
		visual = { a = { fg = p.on_accent, bg = p.visual } },
		replace = { a = { fg = p.on_accent, bg = p.alert } },
		inactive = {
			a = { fg = p.subtle, bg = p.bg },
			b = { fg = p.subtle, bg = p.bg },
			c = { fg = p.subtle },
		},
	}
end

--- Switch colorscheme and statusline. Without a name, re-reads the state file.
function M.apply(name)
	name = name or M.current()
	local p = M.palette(name)
	if not p then
		vim.notify("theme: no palette for '" .. tostring(name) .. "'", vim.log.levels.WARN)
		return
	end
	-- Mode first: catppuccin, gruvbox and everforest pick their variant from it.
	if p.mode and vim.o.background ~= p.mode then
		vim.o.background = p.mode
	end
	vim.cmd.colorscheme(p.nvim)
	local ok, lualine = pcall(require, "lualine")
	if ok then
		lualine.setup(vim.tbl_deep_extend("force", lualine.get_config(), {
			options = { theme = M.lualine_theme(p) },
		}))
	end
	return name
end

return M
