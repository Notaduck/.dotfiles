-- dwm-style layouts per tab. A tab with a layout keeps a client order (master first) and its split
-- tree is rebuilt from that order whenever a pane opens or closes there, or the layout changes.
-- Floating and parked blocks are left alone, as dwm leaves floating windows.

local DEFAULT_MFACT = 0.55
local MFACT_STEP = 0.05
local MFACT_MIN = 0.1
local MFACT_MAX = 0.9
-- New panes become the master, as in dwm; false appends them to the stack (dwm's attachbottom).
local ATTACH_AS_MASTER = true
-- Cells a divider moves to measure how many cells one unit of a split's ratio is.
local CALIBRATE_CELLS = 4
local RATIO_TOLERANCE = 0.01
local RATIO_PASSES = 3
local SETTLE_MS = 50
-- pane_created reaches only panes this window opens; `tern split` and other clients are caught here.
local POLL_MS = 1000
local PICK_DELAY_MS = 60
local KV_KEY = "tabs"
local QUIET = { focus = false }

local LAYOUTS = { "tile", "monocle", "spiral", "dwindle", "grid" }
local SYMBOLS = { tile = "[]=", monocle = "[M]", spiral = "[@]", dwindle = "[\\]", grid = "HHH" }
local UNMANAGED_SYMBOL = "><>"
local ICON = "columns"
local ICONS = { tile = "split", monocle = "expand", spiral = "layers", dwindle = "corner-down-right", grid = "columns" }
local TITLES = {
	tile = "Tile",
	monocle = "Monocle",
	spiral = "Fibonacci spiral",
	dwindle = "Fibonacci dwindle",
	grid = "Grid",
}
local USES_MFACT = { tile = true, spiral = true, dwindle = true }

type Tree = { pane: number?, split: ("right" | "down")?, ratio: number?, [number]: Tree }
type TabState = { layout: string, prev: string?, mfact: number, order: { number } }

local tabs: { [string]: TabState } = tern.kv.get(KV_KEY) or {}
local applying = false
local pending = false

local function save()
	tern.kv.set(KV_KEY, tabs)
	tern.chrome.refresh()
end

-- Trees -------------------------------------------------------------------------------------------

local function leaf(pane: number): Tree
	return { pane = pane }
end

local function split(dir: "right" | "down", ratio: number, first: Tree, second: Tree): Tree
	return { split = dir, ratio = ratio, first, second }
end

-- Equal shares along `dir`: n1 | (n2 | (n3 …)) with each first child taking 1/remaining.
local function chain(nodes: { Tree }, dir: "right" | "down", from: number): Tree
	if from == #nodes then
		return nodes[from]
	end
	return split(dir, 1 / (#nodes - from + 1), nodes[from], chain(nodes, dir, from + 1))
end

local function leaves_of(panes: { number }, from: number, to: number): { Tree }
	local out = {}
	for i = from, to do
		table.insert(out, leaf(panes[i]))
	end
	return out
end

local function tile(order: { number }, mfact: number): Tree
	if #order == 1 then
		return leaf(order[1])
	end
	return split("right", mfact, leaf(order[1]), chain(leaves_of(order, 2, #order), "down", 1))
end

-- dwm's fibonacci patch: each client halves what is left. The spiral turns clockwise inward
-- (right, down, left, up); dwindle always gives the rest the bottom-right.
local function fibonacci(order: { number }, mfact: number, spiral: boolean): Tree
	local function node(i: number): Tree
		if i == #order then
			return leaf(order[i])
		end
		local r = if i == 1 then mfact else 0.5
		local turn = (i - 1) % (if spiral then 4 else 2)
		local here, rest = leaf(order[i]), node(i + 1)
		if turn == 0 then
			return split("right", r, here, rest)
		elseif turn == 1 then
			return split("down", r, here, rest)
		elseif turn == 2 then
			return split("right", 1 - r, rest, here)
		end
		return split("down", 1 - r, rest, here)
	end
	return node(1)
end

-- dwm's gaplessgrid: ceil(sqrt(n)) columns, the rightmost columns taking one extra row.
local function grid(order: { number }): Tree
	local n = #order
	local cols = math.ceil(math.sqrt(n))
	local rows = n // cols
	local extra = n % cols
	local columns: { Tree } = {}
	local at = 1
	for c = 1, cols do
		local count = rows + (if c > cols - extra then 1 else 0)
		table.insert(columns, chain(leaves_of(order, at, at + count - 1), "down", 1))
		at += count
	end
	return chain(columns, "right", 1)
end

local function target(st: TabState): Tree?
	local order = st.order
	if #order == 0 or st.layout == "monocle" then
		return nil
	elseif st.layout == "tile" then
		return tile(order, st.mfact)
	elseif st.layout == "spiral" or st.layout == "dwindle" then
		return fibonacci(order, st.mfact, st.layout == "spiral")
	end
	return grid(order)
end

local function first_leaf(t: Tree): number
	while not t.pane do
		t = t[1]
	end
	return t.pane :: number
end

local function collect(t: Tree?, out: { number }): { number }
	if t then
		if t.pane then
			table.insert(out, t.pane)
		else
			collect(t[1], out)
			collect(t[2], out)
		end
	end
	return out
end

local function same_shape(a: Tree?, b: Tree?): boolean
	if not a or not b then
		return a == b
	elseif a.pane or b.pane then
		return a.pane == b.pane
	end
	return a.split == b.split and same_shape(a[1], b[1]) and same_shape(a[2], b[2])
end

local function node_at(root: Tree?, path: { number }): Tree?
	local t = root
	for _, i in path do
		if not t or t.pane then
			return nil
		end
		t = t[i]
	end
	return t
end

-- Split nodes top-down as {path, ratio}, so an outer divider is set before the ones inside it.
local function ratios(t: Tree, path: { number }, out: { any }): { any }
	if not t.pane then
		table.insert(out, { path = path, ratio = t.ratio })
		for i = 1, 2 do
			local sub = table.clone(path)
			table.insert(sub, i)
			ratios(t[i], sub, out)
		end
	end
	return out
end

-- Layout ----------------------------------------------------------------------------------------

local function root_of(cx, tab: number): Tree?
	local lay = cx.session:layout(tab)
	return if lay then lay.root else nil
end

-- Splitting a pane with `move` makes a 0.5 split with the anchor first. Building top-down from
-- each subtree's first leaf turns any tree into those moves.
local function realize(cx, node: Tree)
	if node.pane then
		return
	end
	local a, b = first_leaf(node[1]), first_leaf(node[2])
	if not cx.layout:move(b, a, node.split, QUIET) then
		tern.log.warn("tiling: move failed", b, a, node.split)
	end
	realize(cx, node[1])
	realize(cx, node[2])
end

-- The leaf of the first side that touches the divider, so resizing it moves exactly that divider.
local function edge_leaf(node: Tree): number
	local t = node[1]
	while not t.pane do
		t = if t.split == node.split then t[2] else t[1]
	end
	return t.pane :: number
end

-- Panes resize in cells, splits store ratios: move the divider a little to learn the scale, then
-- correct with the measured scale (a tab revealed moments ago can report a stale first measure).
local function set_ratio(cx, tab: number, path: { number }, want: number)
	local per_cell: number? = nil
	for _ = 1, RATIO_PASSES do
		local node = node_at(root_of(cx, tab), path)
		if not node or node.pane then
			return
		end
		local now = node.ratio or 0.5
		if math.abs(now - want) < RATIO_TOLERANCE then
			return
		end
		local cells = if per_cell
			then math.round((want - now) / per_cell)
			else (if want > now then CALIBRATE_CELLS else -CALIBRATE_CELLS)
		if cells == 0 or not cx.layout:resize(edge_leaf(node), node.split :: string, cells) then
			return
		end
		local moved = node_at(root_of(cx, tab), path)
		local after = if moved and moved.ratio then moved.ratio else now
		if after == now then
			return
		end
		per_cell = (after - now) / cells
	end
end

local function focused_tab(cx): number?
	local pane = cx.session:focused()
	return if pane then cx.session:tab_of(pane) else nil
end

local function zoomed(cx, tab: number): boolean
	local lay = cx.session:layout(tab)
	return lay ~= nil and lay.zoomed
end

-- Keeps the stored order for panes still there and attaches the new ones.
local function reconcile(order: { number }, present: { number }): { number }
	local here: { [number]: boolean } = {}
	for _, p in present do
		here[p] = true
	end
	local known: { [number]: boolean } = {}
	local kept = {}
	for _, p in order do
		if here[p] and not known[p] then
			known[p] = true
			table.insert(kept, p)
		end
	end
	local fresh = {}
	for _, p in present do
		if not known[p] then
			table.insert(fresh, p)
		end
	end
	if ATTACH_AS_MASTER then
		table.move(kept, 1, #kept, #fresh + 1, fresh)
		return fresh
	end
	table.move(fresh, 1, #fresh, #kept + 1, kept)
	return kept
end

local function apply(cx, tab: number)
	local st = tabs[tostring(tab)]
	if not st then
		return
	end
	local root = root_of(cx, tab)
	st.order = reconcile(st.order, collect(root, {}))
	if st.layout == "monocle" then
		if focused_tab(cx) == tab and not zoomed(cx, tab) and #st.order > 1 then
			cx:command("zoom")
		end
		return
	end
	local want = target(st)
	if not want then
		return
	end
	applying = true
	local ok, err = pcall(function()
		if not same_shape(root, want) then
			realize(cx, want)
		end
		for _, r in ratios(want, {}, {}) do
			set_ratio(cx, tab, r.path, r.ratio)
		end
	end)
	applying = false
	if not ok then
		tern.log.warn("tiling: apply failed", err)
	end
end

local function set_layout(cx, layout: string?)
	local tab = focused_tab(cx)
	if not tab then
		return
	end
	local key = tostring(tab)
	local st = tabs[key]
	if st and st.layout == "monocle" and layout ~= "monocle" and zoomed(cx, tab) then
		cx:command("zoom")
	end
	if not layout then
		tabs[key] = nil
		save()
		cx:toast("info", "Tiling off", "Panes stay where they are")
		return
	end
	if not st then
		st = { layout = layout, mfact = DEFAULT_MFACT, order = collect(root_of(cx, tab), {}) }
		tabs[key] = st
	elseif st.layout ~= layout then
		st.prev = st.layout
		st.layout = layout
	end
	apply(cx, tab)
	save()
	cx:toast("info", SYMBOLS[layout] .. "  " .. TITLES[layout])
end

local function managed(cx): (number?, TabState?)
	local tab = focused_tab(cx)
	if not tab then
		return nil, nil
	end
	return tab, tabs[tostring(tab)]
end

-- Re-tiles every managed tab whose panes changed; closed tabs drop their state.
local function settle(cx)
	pending = false
	local changed = false
	for key, st in tabs do
		local tab = tonumber(key) :: number
		local lay = cx.session:layout(tab)
		if not lay then
			tabs[key] = nil
			changed = true
		else
			local present = collect(lay.root, {})
			local order = reconcile(st.order, present)
			local same = #order == #st.order
			for i = 1, #order do
				same = same and order[i] == st.order[i]
			end
			if not same then
				apply(cx, tab)
				changed = true
			end
		end
	end
	if changed then
		save()
	end
end

local function schedule()
	if applying or pending then
		return
	end
	pending = true
	tern.timer(SETTLE_MS, function(cx)
		if cx then
			settle(cx)
		else
			pending = false
		end
	end)
end

tern.on("pane_created", function(_ev, _cx)
	schedule()
end)
tern.on("pane_closed", function(_ev, _cx)
	schedule()
end)
tern.on("tab_closed", function(_ev, _cx)
	schedule()
end)

local function poll()
	tern.timer(POLL_MS, function(cx)
		if cx and not applying and not pending and next(tabs) ~= nil then
			local ok, err = pcall(settle, cx)
			if not ok then
				tern.log.warn("tiling: settle failed", err)
			end
		end
		poll()
	end)
end
poll()

-- Monocle shows the focused pane: focusing another pane zooms it in turn.
tern.on("focus", function(ev, cx)
	if applying or not ev.pane then
		return
	end
	local tab = cx.session:tab_of(ev.pane)
	local st = if tab then tabs[tostring(tab)] else nil
	if st and st.layout == "monocle" and not zoomed(cx, tab :: number) then
		local root = root_of(cx, tab :: number)
		if root and not root.pane then
			cx:command("zoom")
		end
	end
end)

-- Status line: the layout symbol; a click opens the layout menu.
tern.chrome.status(function(pane)
	local st = if pane.tab then tabs[tostring(pane.tab)] else nil
	return { { text = if st then SYMBOLS[st.layout] else UNMANAGED_SYMBOL, tone = "muted", command = "plugin.tiling.pick" } }
end)

-- Commands --------------------------------------------------------------------------------------

local KEYS = { tile = "ctrl+b>t", monocle = "ctrl+b>m", spiral = "ctrl+b>f", dwindle = "ctrl+b>d", grid = "ctrl+b>=" }
local DETAILS = {
	tile = "main pane left, the rest stacked right",
	monocle = "focused pane fills the tab",
	spiral = "each pane halves the rest, turning clockwise",
	dwindle = "each pane halves the rest, toward the bottom-right",
	grid = "equal grid, no gaps",
}

tern.command({
	id = "pick",
	title = "Tiling: Choose layout…",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>shift+l" },
	run = function(cx)
		local _, st = managed(cx)
		local items = {}
		for _, name in LAYOUTS do
			table.insert(items, {
				label = SYMBOLS[name] .. "  " .. TITLES[name],
				icon = ICONS[name],
				detail = DETAILS[name],
				current = st ~= nil and st.layout == name,
				layout = name,
			})
		end
		table.insert(items, {
			label = UNMANAGED_SYMBOL .. "  Off",
			icon = "x",
			detail = "stop tiling this tab",
			current = st == nil,
			layout = false,
		})
		-- Opened a beat later: from a chord, the key's text would otherwise land in the picker's field.
		tern.timer(PICK_DELAY_MS, function(pcx)
			if not pcx then
				return
			end
			pcx:pick({ items = items, placeholder = "Layout for this tab", icon = ICON, action = "apply" }):next(function(item)
				if item then
					tern.timer(0, function(wcx)
						if wcx then
							set_layout(wcx, if item.layout then item.layout else nil)
						end
					end)
				end
			end)
		end)
	end,
})

for _, name in LAYOUTS do
	tern.command({
		id = name,
		title = "Tiling: " .. TITLES[name] .. "  " .. SYMBOLS[name],
		icon = ICONS[name],
		group = "Tiling",
		keys = { KEYS[name] },
		run = function(cx)
			set_layout(cx, name)
		end,
	})
end

tern.command({
	id = "off",
	title = "Tiling: Off (stop tiling this tab)",
	icon = "x",
	group = "Tiling",
	keys = { "ctrl+b>o" },
	run = function(cx)
		set_layout(cx, nil)
	end,
})

tern.command({
	id = "cycle",
	title = "Tiling: Next layout",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>space" },
	run = function(cx)
		local _, st = managed(cx)
		local next_layout = LAYOUTS[1]
		if st then
			local i = table.find(LAYOUTS, st.layout) or 0
			next_layout = LAYOUTS[i % #LAYOUTS + 1]
		end
		set_layout(cx, next_layout)
	end,
})

tern.command({
	id = "last",
	title = "Tiling: Previous layout",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>tab" },
	run = function(cx)
		local _, st = managed(cx)
		if st and st.prev then
			set_layout(cx, st.prev)
		end
	end,
})

-- dwm's zoom: the focused pane becomes the master; on the master, it swaps with the next one.
tern.command({
	id = "zoom",
	title = "Tiling: Make focused pane the master",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>enter" },
	run = function(cx)
		local tab, st = managed(cx)
		local pane = cx.session:focused()
		if not tab or not st or not pane then
			return
		end
		local order = reconcile(st.order, collect(root_of(cx, tab), {}))
		local at = table.find(order, pane)
		if not at or #order < 2 then
			return
		end
		table.remove(order, at)
		table.insert(order, if at == 1 then 2 else 1, pane)
		st.order = order
		apply(cx, tab)
		save()
	end,
})

local function nudge_mfact(cx, delta: number)
	local tab, st = managed(cx)
	if not tab or not st or not USES_MFACT[st.layout] then
		return
	end
	st.mfact = math.clamp(st.mfact + delta, MFACT_MIN, MFACT_MAX)
	apply(cx, tab)
	save()
end

tern.command({
	id = "grow_master",
	title = "Tiling: Grow master",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>]" },
	run = function(cx)
		nudge_mfact(cx, MFACT_STEP)
	end,
})

tern.command({
	id = "shrink_master",
	title = "Tiling: Shrink master",
	icon = ICON,
	group = "Tiling",
	keys = { "ctrl+b>[" },
	run = function(cx)
		nudge_mfact(cx, -MFACT_STEP)
	end,
})
