-- tmux-style pane keys: <prefix> h/j/k/l focuses, <prefix> v enters move mode (h/j/k/l move the
-- focused pane, escape leaves), and unfocused panes are dimmed harder than Tern's default.

local DIRS = { h = "left", j = "down", k = "up", l = "right" }
local EXIT_ACTION = "plugin.pane-keys.move_mode_exit"
local SAVED_KEY = "saved_keybinds"

local DIM_CSS = [[
.tn-pane.dim .tn-veil { opacity: 0.5; }
]]

local MOVE_CSS = [[
.tn-pane.on { outline: 2px solid var(--accent); outline-offset: -2px; }
]]

local function copy(t: { [string]: any }): { [string]: any }
	local out = {}
	for k, v in t do
		out[k] = v
	end
	return out
end

local function current_keybinds(cx): { [string]: any }
	return copy(cx.settings:get("keybinds") or {})
end

-- Static chords live in settings.json so they show on the Keyboard page; the prefix follows
-- `keymap_prefix`. Only missing chords are added, so the user's own edits win.
local function ensure_static_binds(cx)
	local binds = current_keybinds(cx)
	local prefix = cx.settings:get("keymap_prefix") or "ctrl+b"
	local changed = false
	for key, dir in DIRS do
		local chord = prefix .. ">" .. key
		if binds[chord] == nil then
			binds[chord] = "focus_pane:" .. dir
			changed = true
		end
	end
	local move_chord = prefix .. ">v"
	if binds[move_chord] == nil then
		binds[move_chord] = "plugin.pane-keys.move_mode"
		changed = true
	end
	if changed then
		cx.settings:set("keybinds", binds)
	end
end

local MODE_KEYS = { "h", "j", "k", "l", "escape" }

local function in_move_mode(): boolean
	local state = tern.kv.get(SAVED_KEY)
	return state ~= nil and state.active == true
end

-- Puts back whatever h/j/k/l/escape were bound to before the mode, leaving every other bind as it
-- is now.
local function exit_move_mode(cx)
	local state = tern.kv.get(SAVED_KEY)
	if state == nil then
		return
	end
	local prior = state.prior or {}
	local binds = current_keybinds(cx)
	for _, key in MODE_KEYS do
		binds[key] = prior[key]
	end
	cx.settings:set("keybinds", binds)
	tern.kv.set(SAVED_KEY, nil)
	tern.css("move", "")
end

local function enter_move_mode(cx)
	if in_move_mode() then
		return
	end
	local binds = current_keybinds(cx)
	local prior = {}
	for _, key in MODE_KEYS do
		prior[key] = binds[key]
	end
	tern.kv.set(SAVED_KEY, { active = true, prior = prior })
	for key, dir in DIRS do
		binds[key] = "move_pane:" .. dir
	end
	binds.escape = EXIT_ACTION
	cx.settings:set("keybinds", binds)
	tern.css("move", MOVE_CSS)
	cx:toast("info", "Move pane", "h j k l move the focused pane · esc leaves")
end

tern.css("dim", DIM_CSS)

tern.command({
	id = "move_mode",
	title = "Move Pane Mode",
	icon = "move",
	run = enter_move_mode,
})

tern.command({
	id = "move_mode_exit",
	title = "Leave Move Pane Mode",
	icon = "move",
	available = function()
		return in_move_mode()
	end,
	run = exit_move_mode,
})

tern.on("window_start", function(cx)
	-- A window that closed (or a reload) mid-mode would leave bare h/j/k/l bound.
	exit_move_mode(cx)
	ensure_static_binds(cx)
end)
