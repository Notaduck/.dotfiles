-- The Work block as a sidebar: pinned to the right edge of whichever tab is shown, following tab switches
-- without taking focus, its width share kept in tern.kv. Also publishes the focused pane's cwd (the Ideas
-- tab's "this project" section) and loads ideas into omp chats for the `ideas://` links the block opens.
--
-- The panel placement (pin, rightShare, sizeTo and follow) is adapted from the Projects panel of Overseer
-- (https://github.com/mmnavarr/overseer, MIT License, Copyright (c) 2026 Malcolm Navarro), mirrored to the
-- right edge.

local BLOCK = "jira-sprint.sprint"
local HOME = tern.getenv("HOME") or "~"
-- Shared with the block (host.luau, ideas.luau).
local FOCUS_CWD_KEY = "focus-cwd"
local TAB_KEY = "tab"
local SHARE_KEY = "panel-share"
local OPEN_KEY = "panel-open"
local DEFAULT_SHARE = 0.24
local MIN_SHARE, MAX_SHARE = 0.15, 0.45

local M = {}

local share = math.clamp(tonumber(tern.kv.get(SHARE_KEY)) or DEFAULT_SHARE, MIN_SHARE, MAX_SHARE)
-- Whether you want the panel shown; it reopens after vanishing with its tab.
local wantPanel = tern.kv.get(OPEN_KEY) == true
-- The tab the panel was last placed in, to tell a closed panel from a closed tab.
local panelTab = nil
-- The last focused pane that isn't the sidebar, and when each agent pane last had focus.
local lastPane = nil
local agentFocusedAt = {}

local function setWantPanel(want)
	wantPanel = want
	tern.kv.set(OPEN_KEY, want)
end

local function sidebarPane(cx)
	for _, p in cx.session:panes() do
		if p.block == BLOCK then
			return p.pane
		end
	end
	return nil
end

local function shownTab(cx)
	local focused = cx.session:focused()
	return focused and cx.session:tab_of(focused)
end

-- Focus tracking ----------------------------------------------------------------------------------

local function isAgent(cx, pane)
	for _, a in cx.agents:list() do
		if a.pane == pane then
			return true
		end
	end
	return false
end

-- Publishes the focused pane's cwd for the Ideas tab, ignoring the sidebar itself.
local function trackFocus(cx)
	local focused = cx.session:focused()
	local info = focused and cx.session:pane(focused)
	if not info or info.block == BLOCK then
		return
	end
	lastPane = info.pane
	if isAgent(cx, info.pane) then
		agentFocusedAt[info.pane] = tern.now()
	end
	if info.cwd and info.cwd ~= "" and tern.kv.get(FOCUS_CWD_KEY) ~= info.cwd then
		tern.kv.set(FOCUS_CWD_KEY, info.cwd)
	end
end

-- Panel -------------------------------------------------------------------------------------------

local QUIET = { focus = false }
-- Ratio steering (as the tiling plugin does it): calibrate with a few cells, then correct by the measured
-- ratio per cell, since a tab revealed moments ago can report stale cells.
local CALIBRATE_CELLS = 4
local RATIO_TOLERANCE = 0.01
local RATIO_PASSES = 4

local function firstLeaf(tree)
	while not tree.pane do
		tree = tree[1]
	end
	return tree.pane
end

-- `tree` without `pane`: its split collapses into the sibling. nil when `pane` was all of it.
local function without(tree, pane)
	if not tree then
		return nil
	end
	if tree.pane then
		return if tree.pane == pane then nil else tree
	end
	local a, b = without(tree[1], pane), without(tree[2], pane)
	if not a then
		return b
	elseif not b then
		return a
	end
	return { split = tree.split, ratio = tree.ratio, a, b }
end

local function rootOf(cx, tab)
	local layout = cx.session:layout(tab)
	return layout and layout.root
end

-- Whether the panel is the right side of the tab's top split: full height on the right edge.
local function pinned(root, pane)
	return root ~= nil and root.split == "right" and root[2].pane == pane
end

-- The panel's share of the tab's width while pinned, else nil.
local function rightShare(cx, tab, pane)
	local root = rootOf(cx, tab)
	return if pinned(root, pane) then 1 - root.ratio else nil
end

local function nodeAt(root, path)
	local t = root
	for _, i in path do
		if not t or t.pane then
			return nil
		end
		t = t[i]
	end
	return t
end

-- Moves the divider of the split at `path` to `want`. Tern resizes in cells, splits store ratios. It grows
-- the second side's first leaf (which always touches the divider) back over it: growing a first-side leaf
-- toward the divider can move a nested divider instead.
local BACK = { right = "left", down = "up" }
local function setRatio(cx, tab, path, want)
	local perCell = nil
	for _ = 1, RATIO_PASSES do
		local node = nodeAt(rootOf(cx, tab), path)
		if not node or node.pane then
			return
		end
		local now = node.ratio or 0.5
		if math.abs(now - want) < RATIO_TOLERANCE then
			return
		end
		local cells = if perCell then math.round((want - now) / perCell) elseif want > now then CALIBRATE_CELLS else -CALIBRATE_CELLS
		if cells == 0 or not cx.layout:resize(firstLeaf(node[2]), BACK[node.split], -cells) then
			return
		end
		local moved = nodeAt(rootOf(cx, tab), path)
		local after = if moved and moved.ratio then moved.ratio else now
		if after == now then
			return
		end
		perCell = (after - now) / cells
	end
end

-- Rebuilds `node` top-down: moving each split's second first-leaf beside its first first-leaf (a 0.5
-- split) turns any arrangement of the same leaves into this tree.
local function realize(cx, node)
	if node.pane then
		return
	end
	cx.layout:move(firstLeaf(node[2]), firstLeaf(node[1]), node.split, QUIET)
	realize(cx, node[1])
	realize(cx, node[2])
end

local function restoreRatios(cx, tab, node, path)
	if node.pane then
		return
	end
	setRatio(cx, tab, path, node.ratio or 0.5)
	for i = 1, 2 do
		local sub = table.clone(path)
		table.insert(sub, i)
		restoreRatios(cx, tab, node[i], sub)
	end
end

-- Remembers the width you left the panel at in `tab`.
local function rememberShare(cx, tab, pane)
	local current = tab and rightShare(cx, tab, pane)
	if current and math.abs(current - share) > 0.01 then
		share = math.clamp(current, MIN_SHARE, MAX_SHARE)
		tern.kv.set(SHARE_KEY, share)
	end
end

-- Makes the panel the full-height right side of `tab`, the tab's other panes keeping their arrangement on
-- the left, unless it is already there.
local function pin(cx, pane, tab)
	local root = rootOf(cx, tab)
	if not root then
		return
	end
	local from = cx.session:tab_of(pane)
	if from == tab and pinned(root, pane) then
		panelTab = tab
		return
	end
	local rest = without(root, pane)
	if not rest then
		return
	end
	rememberShare(cx, from, pane)
	if from ~= tab then
		if from then
			cx.layout:move_to_tab(pane, tab, QUIET)
		else
			cx.layout:unpark(pane, QUIET)
		end
	end
	cx.layout:move(pane, firstLeaf(rest), "right", QUIET)
	realize(cx, rest)
	restoreRatios(cx, tab, rest, { 1 })
	setRatio(cx, tab, {}, 1 - share)
	panelTab = tab
	-- Right after the moves a resize can still measure the old layout; correct the width once it settled.
	tern.timer(150, function(later)
		if later and pinned(rootOf(later, tab), pane) then
			setRatio(later, tab, {}, 1 - share)
		end
	end)
end

local function openPanel(cx, tab, focus, which)
	local root = rootOf(cx, tab)
	local target = root and firstLeaf(root)
	local args = if which then { which } else nil
	local pane = cx:new_block(BLOCK, args, "beside", { focus = focus, target = target, dir = "right", ratio = share })
	if not pane then
		cx:toast("error", "Couldn't open the Work sidebar")
		return nil
	end
	-- The new pane joins the layout after this call returns; pin it once it is there.
	tern.timer(50, function(later)
		if later then
			pin(later, pane, tab)
		end
	end)
	if focus then
		cx.layout:focus(pane)
	end
	panelTab = tab
	return pane
end

-- Keeps the panel in the shown tab; runs after every tab, pane and focus change.
local function follow(cx)
	if not wantPanel then
		return
	end
	local tab = shownTab(cx)
	if not tab then
		return
	end
	local pane = sidebarPane(cx)
	if not pane then
		-- Gone while its tab remains: you closed it. Gone with its tab: bring it back here.
		for _, info in cx.session:tabs() do
			if info.id == panelTab then
				setWantPanel(false)
				panelTab = nil
				return
			end
		end
		openPanel(cx, tab, false, nil)
		return
	end
	-- Alone in the shown tab (its last other pane closed): park it until another tab shows.
	if cx.session:tab_of(pane) == tab and not without(rootOf(cx, tab), pane) then
		cx.layout:park(pane)
		return
	end
	pin(cx, pane, tab)
end

local followQueued = false
local function followSoon()
	if followQueued then
		return
	end
	followQueued = true
	tern.timer(0, function(cx)
		followQueued = false
		if not cx then
			return
		end
		local ok, err = pcall(trackFocus, cx)
		if not ok then
			tern.log.warn("Work sidebar: focus tracking: " .. tostring(err))
		end
		ok, err = pcall(follow, cx)
		if not ok then
			tern.log.warn("Work sidebar: " .. tostring(err))
		end
	end)
end

-- The sidebar pane when it shows in the shown tab.
local function shownPane(cx)
	local tab = shownTab(cx)
	local pane = sidebarPane(cx)
	if pane and tab and cx.session:tab_of(pane) == tab then
		return pane
	end
	return nil
end

local function hide(cx, pane)
	rememberShare(cx, cx.session:tab_of(pane), pane)
	setWantPanel(false)
	panelTab = nil
	cx.layout:close(pane)
end

-- Shows the panel in the shown tab and focuses it, on tab `which` (nil: the block's own).
local function show(cx, which)
	local tab = shownTab(cx)
	if not tab then
		return
	end
	setWantPanel(true)
	local pane = sidebarPane(cx)
	if not pane then
		openPanel(cx, tab, true, which)
		return
	end
	pin(cx, pane, tab)
	if which then
		cx.session:event(pane, { ev = "action", id = "main.tabs", act = "tab=" .. which })
	end
	cx.layout:focus(pane)
end

-- ctrl+b i: hides the panel when it shows, else shows it on the last used tab.
function M.toggle(cx)
	local pane = shownPane(cx)
	if pane then
		hide(cx, pane)
	else
		show(cx, nil)
	end
end

-- ctrl+b shift+i: shows the panel on Ideas, or hides it when it already shows Ideas.
function M.toggleIdeas(cx)
	local pane = shownPane(cx)
	if pane and tern.kv.get(TAB_KEY) == "ideas" then
		hide(cx, pane)
	else
		show(cx, "ideas")
	end
end

-- Loading ideas -----------------------------------------------------------------------------------

local function urlDecode(s: string): string
	s = string.gsub(s, "+", " ")
	return (string.gsub(s, "%%(%x%x)", function(h)
		return string.char(tonumber(h, 16) :: number)
	end))
end

local function queryParam(query: string, name: string): string?
	for pair in string.gmatch(query, "[^&]+") do
		local k, v = string.match(pair, "^([^=]*)=?(.*)$")
		if k == name and v ~= "" then
			return urlDecode(v :: string)
		end
	end
	return nil
end

-- Starts a new chat beside the last pane you worked in (not the sidebar).
local function startNew(cx, id: string, project: string?)
	if lastPane and cx.session:pane(lastPane) and cx.session:tab_of(lastPane) == shownTab(cx) then
		cx.layout:focus(lastPane)
	end
	local cwd = if project and tern.fs.exists(project) then project else HOME
	local pane = cx.agents:start({ prompt = "/idea open " .. id, cwd = cwd, how = "split" })
	tern.log.info("Work sidebar: started a chat (pane " .. tostring(pane) .. ") with /idea open " .. id)
	-- A split agent start can park the tab's other panes after its pane_created event; bring the panel back.
	tern.timer(500, function(later)
		if later then
			followSoon()
		end
	end)
end

-- The chat "this chat" means: the last focused pane when it's an agent, else the agent in the shown tab
-- that had focus most recently.
local function targetAgent(cx)
	local tab = shownTab(cx)
	local best, bestAt = nil, -1
	for _, a in cx.agents:list() do
		if a.state ~= "exited" and cx.session:tab_of(a.pane) == tab then
			if a.pane == lastPane then
				return a
			end
			local at = agentFocusedAt[a.pane] or 0
			if at > bestAt then
				best, bestAt = a, at
			end
		end
	end
	return best
end

local function loadIdea(cx, id: string, project: string?)
	local target = targetAgent(cx)
	if not target then
		startNew(cx, id, project)
		return
	end
	if target.state ~= "idle" then
		cx:toast("info", "That chat is busy", "Opening " .. id .. " in a new chat")
		startNew(cx, id, project)
		return
	end
	cx.agents:ask(target.pane, "/idea open " .. id)
	cx.layout:focus(target.pane)
	tern.log.info("Work sidebar: asked pane " .. target.pane .. " to /idea open " .. id)
end

-- `ideas://load/<id>[?project=…]` and `ideas://new/<id>[?project=…]`; nil for other links.
function M.link(url: string, cx): boolean
	local kind, rawId, query = string.match(url, "^ideas://(%a+)/([^?#]+)%??([^#]*)")
	if not kind then
		return false
	end
	local id = urlDecode(rawId :: string)
	local project = queryParam(query or "", "project")
	local ok, err = pcall(function()
		if kind == "load" then
			loadIdea(cx, id, project)
		elseif kind == "new" then
			startNew(cx, id, project)
		else
			cx:toast("error", "Unknown ideas link", url)
		end
	end)
	if not ok then
		tern.log.warn("Work sidebar: " .. url .. ": " .. tostring(err))
		cx:toast("error", "Couldn't load " .. id, tostring(err))
	end
	return true
end

-- Wiring ------------------------------------------------------------------------------------------

tern.on("window_start", function(_cx)
	followSoon()
end)
for _, name in { "focus", "cwd", "tab_created", "tab_closed", "pane_created", "pane_closed" } do
	tern.on(name, function(_ev, _cx)
		followSoon()
	end)
end

return M
