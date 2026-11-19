-- The Sessions tab of the Work block: a control tower for omp sessions. "Open" lists the omp panes running
-- now (published to tern.kv by window.luau), "Recent" the sessions of the last 30 days that aren't open
-- (`omp-sessions list`). Typing filters; a row's button, double-click or Enter jumps to an open pane or
-- resumes a closed session in a new tab.
--
-- The block runs host-side, without `cx.agents` or `cx.layout`: it opens `work://session/jump/<pane>` and
-- `work://session/resume/<id>?cwd=…` links, which window.luau claims. The Sprint and Ideas tabs ask
-- `M.find` which session belongs to an issue or idea.

local HOME = tern.getenv("HOME") or ""
local CLI = HOME .. "/.local/bin/omp-sessions"
local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local CLI_TIMEOUT_MS = 20000
local TICK_MS = 2000
-- Refresh cadence of the session list: while the tab shows, and (for the other tabs' markers) while it doesn't.
local REFRESH_SHOWN_S = 30
local REFRESH_HIDDEN_S = 300
-- Published by the window half (window.luau): the open omp panes.
local AGENTS_KEY = "open-agents"
local TABLES = { ["main.sessions-open"] = true, ["main.sessions-recent"] = true }
local KEY_PATTERN = "%f[%w](%u[%u%d]+%-%d+)%f[^%w]"
local STATE_BADGE = {
	working = { text = "working", tone = "info" },
	waiting_input = { text = "waiting", tone = "warning" },
	idle = { text = "idle", tone = "muted" },
}

local ui = tern.ui

export type Session = {
	id: string,
	title: string,
	cwd: string,
	modified: number?,
	keys: { string },
	ideas: { string },
	recap: string?,
	-- Precomputed for the view: the title without icon glyphs, the project label and the filter text.
	label: string,
	project: string,
	haystack: string,
}
export type Agent = {
	pane: number,
	title: string,
	cwd: string,
	state: string,
	-- The session id from the pane's command line (`omp --resume <id>`, `omp --restore <file>`), when it shows.
	sid: string?,
	-- The session it runs, matched by id, else by exact title (and cwd).
	session: Session?,
	keys: { string },
	label: string,
	project: string,
	haystack: string,
}
export type State = {
	cx: any,
	alive: () -> boolean,
	render: () -> (),
	shown: () -> boolean,
	sessions: { Session }?,
	by_id: { [string]: Session },
	agents: { Agent },
	agents_stamp: any,
	-- Session ids an open pane runs.
	open_ids: { [string]: Agent },
	-- Jira key -> the open pane / the newest closed session with that key (keys only, not mentions).
	open_by_key: { [string]: Agent },
	closed_by_key: { [string]: Session },
	-- Idea id -> the open pane / newest closed session that worked on it (`ideas` of the session).
	open_by_idea: { [string]: Agent },
	closed_by_idea: { [string]: Session },
	inflight: boolean,
	error: string?,
	updated: number?,
	next_fetch: number,
	query: string,
	selected: string?,
}
export type Link = { open: Agent?, closed: Session? }

local M = {}

-- Helpers -----------------------------------------------------------------------------------------

local function str(v: any): string?
	return if type(v) == "string" and v ~= "" then v else nil
end

local function strings(v: any): { string }
	local out = {}
	if type(v) == "table" then
		for _, x in v do
			if type(x) == "string" then
				table.insert(out, x)
			end
		end
	end
	return out
end

local function first_line(s: string): string
	local line = string.match(s, "[^\r\n]+") or s
	return (string.gsub(line, "^%s+", ""))
end

local function url_encode(s: string): string
	return (string.gsub(s, "[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

-- The title without private-use icon glyphs (omp prefixes titles with a Nerd Font icon the sans face lacks).
local function clean(title: string): string
	local ok, out = pcall(function()
		local kept = {}
		for _, cp in utf8.codes(title) do
			if not ((cp >= 0xE000 and cp <= 0xF8FF) or cp >= 0xF0000) then
				table.insert(kept, utf8.char(cp))
			end
		end
		return table.concat(kept)
	end)
	return (string.gsub(if ok then out else title, "^%s+", ""))
end

-- The folder name, or `repo/worktree` for a `<repo>-worktrees/<name>` worktree.
local function project(cwd: string): string
	local parent, name = string.match(cwd, "([^/]+)/([^/]+)/*$")
	if parent and name then
		local repo = string.match(parent, "^(.+)%-worktrees$")
		if repo then
			return repo .. "/" .. name
		end
		return name
	end
	return string.match(cwd, "([^/]+)/*$") or cwd
end

local function days_from_civil(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- ISO 8601 UTC ("2026-11-17T15:53:59.905Z") as epoch seconds.
local function parse_time(s: string?): number?
	local y, mo, d, h, mi, sec = string.match(s or "", "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	return days_from_civil(tonumber(y) :: number, tonumber(mo) :: number, tonumber(d) :: number) * 86400
		+ (tonumber(h) :: number) * 3600
		+ (tonumber(mi) :: number) * 60
		+ (tonumber(sec) :: number)
end

local function age(t: number?): string
	if not t then
		return ""
	end
	local d = os.time() - t
	if d < 60 then
		return "now"
	elseif d < 3600 then
		return (d // 60) .. "m"
	elseif d < 86400 then
		return (d // 3600) .. "h"
	elseif d < 14 * 86400 then
		return (d // 86400) .. "d"
	end
	return (d // (7 * 86400)) .. "w"
end

local function add_unique(list: { string }, v: string)
	if not table.find(list, v) then
		table.insert(list, v)
	end
end

-- Jira keys in a pane title and its cwd's folder name (a `<repo>-worktrees/<KEY>` worktree).
local function keys_of(title: string, cwd: string): { string }
	local keys = {}
	for key in string.gmatch(title, KEY_PATTERN) do
		add_unique(keys, key)
	end
	local base = string.match(cwd, "([^/]+)/*$")
	if base and string.match(base, "^%u[%u%d]+%-%d+$") then
		add_unique(keys, base)
	end
	return keys
end

-- Data --------------------------------------------------------------------------------------------

local function parse_sessions(v: any): { Session }
	local out: { Session } = {}
	for _, e in (if type(v) == "table" then v else {}) do
		local id = type(e) == "table" and str(e.id)
		if id then
			local title = str(e.title) or ""
			local cwd = str(e.cwd) or ""
			local keys, ideas = strings(e.keys), strings(e.ideas)
			local label = clean(title)
			local tagged = {}
			for _, i in ideas do
				table.insert(tagged, "idea:" .. i)
			end
			table.insert(out, {
				id = id,
				title = title,
				cwd = cwd,
				modified = parse_time(str(e.modified) or str(e.created)),
				keys = keys,
				ideas = ideas,
				recap = str(e.recap),
				label = label,
				project = project(cwd),
				haystack = string.lower(table.concat({ table.concat(keys, " "), table.concat(tagged, " "), label, cwd, id }, " ")),
			})
		end
	end
	return out
end

-- The session a pane runs: by the id on its command line, else the newest with its exact title, the
-- same cwd preferred.
local function match_session(s: State, a: { title: string, cwd: string, sid: string? }): Session?
	if a.sid and s.by_id[a.sid] then
		return s.by_id[a.sid]
	end
	if a.title == "" then
		return nil
	end
	local any: Session? = nil
	for _, session in s.sessions or {} do
		if session.title == a.title then
			if session.cwd == a.cwd then
				return session
			end
			any = any or session
		end
	end
	return any
end

-- Rebuilds the open/closed indexes after the session list or the open panes changed.
local function reindex(s: State)
	s.by_id = {}
	for _, session in s.sessions or {} do
		s.by_id[session.id] = session
	end
	s.open_ids, s.open_by_key, s.open_by_idea = {}, {}, {}
	for _, a in s.agents do
		a.session = match_session(s, a)
		local keys = keys_of(a.title, a.cwd)
		local tagged = {}
		if a.session then
			s.open_ids[a.session.id] = a
			for _, k in a.session.keys do
				add_unique(keys, k)
			end
			for _, i in a.session.ideas do
				s.open_by_idea[i] = s.open_by_idea[i] or a
				table.insert(tagged, "idea:" .. i)
			end
		end
		a.keys = keys
		for _, k in keys do
			s.open_by_key[k] = s.open_by_key[k] or a
		end
		a.haystack = string.lower(table.concat({ table.concat(keys, " "), table.concat(tagged, " "), a.label, a.cwd }, " "))
	end
	s.closed_by_key, s.closed_by_idea = {}, {}
	for _, session in s.sessions or {} do
		if not s.open_ids[session.id] then
			for _, k in session.keys do
				s.closed_by_key[k] = s.closed_by_key[k] or session
			end
			for _, i in session.ideas do
				s.closed_by_idea[i] = s.closed_by_idea[i] or session
			end
		end
	end
end

local function fetch(s: State)
	if s.inflight then
		return
	end
	s.inflight = true
	s.next_fetch = os.time() + (if s.shown() then REFRESH_SHOWN_S else REFRESH_HIDDEN_S)
	local argv = { CLI, "list", "--json", "--days", "30", "--limit", "200" }
	local opts = { env = { PATH = PATH, HOME = HOME }, timeout_ms = CLI_TIMEOUT_MS }
	local function done(r: any)
		s.inflight = false
		s.updated = os.time()
		if r.status ~= 0 then
			local msg = first_line(r.stderr or "")
			s.error = "omp-sessions failed: " .. (if r.timed_out then "timed out" elseif msg ~= "" then msg else "exit status " .. tostring(r.status))
		else
			local ok, v = pcall(tern.json.decode, r.stdout)
			if ok and type(v) == "table" then
				s.sessions, s.error = parse_sessions(v), nil
				reindex(s)
			else
				s.error = "omp-sessions printed invalid JSON"
			end
		end
		if s.alive() then
			s.render()
		end
	end
	local ok, err = pcall(tern.process.run, argv, opts, done)
	if not ok then
		done({ status = -1, stdout = "", stderr = tostring(err), timed_out = false })
	end
end

-- Reads the open panes the window half published; true when they changed.
local function read_agents(s: State): boolean
	local ok, v = pcall(tern.kv.get, AGENTS_KEY)
	if not ok or type(v) ~= "table" or v.stamp == s.agents_stamp then
		return false
	end
	s.agents_stamp = v.stamp
	local agents: { Agent } = {}
	for _, e in (if type(v.agents) == "table" then v.agents else {}) do
		if type(e) == "table" and type(e.pane) == "number" and e.state ~= "exited" then
			local title = str(e.title) or ""
			local cwd = str(e.cwd) or ""
			table.insert(agents, {
				pane = e.pane,
				title = title,
				cwd = cwd,
				state = str(e.state) or "idle",
				sid = str(e.sid),
				keys = {},
				label = clean(title),
				project = project(cwd),
				haystack = "",
			})
		end
	end
	s.agents = agents
	reindex(s)
	return true
end

local function tick(s: State)
	if not s.alive() then
		return
	end
	local changed = read_agents(s)
	if os.time() >= s.next_fetch then
		fetch(s)
	end
	if changed then
		s.render()
	end
	tern.timer(TICK_MS, function()
		tick(s)
	end)
end

-- Actions -----------------------------------------------------------------------------------------

function M.jump(s: State, a: Agent)
	s.cx:open("work://session/jump/" .. string.format("%d", a.pane))
end

function M.resume(s: State, session: Session)
	s.cx:open("work://session/resume/" .. url_encode(session.id) .. "?cwd=" .. url_encode(session.cwd))
end

-- The open pane and the newest closed session for Jira `keys`, session `ids` and `idea`; nil when neither.
function M.find(s: State, keys: { string }?, ids: { string }?, idea: string?): Link?
	local open: Agent?, closed: Session? = nil, nil
	for _, id in ids or {} do
		open = open or s.open_ids[id]
		local session = s.by_id[id]
		if session and not s.open_ids[id] and (not closed or (session.modified or 0) > (closed.modified or 0)) then
			closed = session
		end
	end
	for _, k in keys or {} do
		open = open or s.open_by_key[k]
		local session = s.closed_by_key[k]
		if session and (not closed or (session.modified or 0) > (closed.modified or 0)) then
			closed = session
		end
	end
	if idea then
		open = open or s.open_by_idea[idea]
		local session = s.closed_by_idea[idea]
		if session and (not closed or (session.modified or 0) > (closed.modified or 0)) then
			closed = session
		end
	end
	if not open and not closed then
		return nil
	end
	return { open = open, closed = closed }
end

-- The marker the Sprint and Ideas rows show: ● an open pane, ○ a session to resume.
function M.marker(link: Link?): any?
	if not link then
		return nil
	end
	if link.open then
		return ui.span(" ●", "success")
	end
	return ui.span(" ○", "muted")
end

-- Row-menu items for `link`, handled by `M.act`.
function M.menu(link: Link?, menu: { string })
	if link and link.open then
		table.insert(menu, "Jump to session")
	end
	if link and link.closed then
		table.insert(menu, "Resume session")
	end
end

-- Runs a row-menu item from `M.menu`; false for any other.
function M.act(s: State, link: Link?, act: string): boolean
	if act == "Jump to session" and link and link.open then
		M.jump(s, link.open)
	elseif act == "Resume session" and link and link.closed then
		M.resume(s, link.closed)
	else
		return false
	end
	return true
end

-- View --------------------------------------------------------------------------------------------

local function keyed(node: any, key: string)
	node.p = node.p or {}
	node.p.key = key
	return node
end

local function keys_cell(keys: { string }): { any }
	local spans: { any } = {}
	for _, k in keys do
		table.insert(spans, ui.span((if #spans > 0 then " " else "") .. k, "strong"))
	end
	return spans
end

local function title_cell(label: string, id: string?): { any }
	if label ~= "" then
		return { ui.span(label) }
	end
	return { ui.span("(untitled)" .. (if id then " " .. string.sub(id, 1, 8) else ""), "muted") }
end

-- The muted second line under a row: project, idea badges and the recap.
local function detail_cell(project: string, ideas: { string }, recap: string?): { any }
	local spans: { any } = { ui.span(project, "muted") }
	for _, i in ideas do
		table.insert(spans, ui.span("  idea:" .. i, "info"))
	end
	if recap then
		table.insert(spans, ui.span("  " .. recap, "muted"))
	end
	return spans
end

-- An open pane as two rows (`open:<pane>`, `open2:<pane>`): state, keys, title and age over the details.
local function open_rows(a: Agent, rows: { any })
	local session = a.session
	local tip = (if a.label ~= "" then a.label .. " · " else "") .. a.cwd
	local menu = { "Jump to pane" }
	local pane = string.format("%d", a.pane)
	table.insert(rows, {
		id = "open:" .. pane,
		title = tip,
		menu = menu,
		cells = {
			{ badge = STATE_BADGE[a.state] or { text = a.state, tone = "muted" } },
			keys_cell(a.keys),
			title_cell(a.label, session and session.id),
			ui.span(age(session and session.modified), "muted"),
			{ button = { text = "Jump", act = "jump", variant = "quiet" } },
		},
	})
	table.insert(rows, {
		id = "open2:" .. pane,
		title = tip,
		menu = menu,
		cells = { {}, {}, detail_cell(a.project, if session then session.ideas else {}, session and session.recap), {}, {} },
	})
end

-- A closed session as two rows (`s:<id>`, `r:<id>`): keys, title and age over the details.
local function recent_rows(session: Session, rows: { any })
	local tip = (if session.label ~= "" then session.label .. " · " else "") .. session.cwd .. " · " .. session.id
	table.insert(rows, {
		id = "s:" .. session.id,
		title = tip,
		menu = { "Resume" },
		cells = {
			keys_cell(session.keys),
			title_cell(session.label, session.id),
			ui.span(age(session.modified), "muted"),
			{ button = { text = "Resume", act = "resume", variant = "quiet" } },
		},
	})
	table.insert(rows, {
		id = "r:" .. session.id,
		title = tip,
		menu = { "Resume" },
		cells = { {}, detail_cell(session.project, session.ideas, session.recap), {}, {} },
	})
end

local function search_box(s: State): any
	local cursor = utf8.len(s.query) or #s.query
	local placeholder = "Type to filter key, title, idea or folder · Esc clears"
	return keyed(ui.node("input", { text = s.query, cursor = cursor, placeholder = placeholder }), "sessions-search")
end

local function toolbar(s: State): any
	local status = if s.inflight then "loading…" elseif s.updated then "last 30 days · updated " .. age(s.updated) else ""
	return ui.row({
		ui.button("Refresh", { actions = { click = "sessions_refresh" }, size = "sm", icon = "refresh", busy = s.inflight }),
		ui.text(ui.span(status, "muted")),
	})
end

local function hit(haystack: string, query: string): boolean
	return query == "" or string.find(haystack, query, 1, true) ~= nil
end

-- API ---------------------------------------------------------------------------------------------

-- `shown` tells whether the block shows this tab.
function M.new(cx: any, alive: () -> boolean, render: () -> (), shown: () -> boolean): State
	local s: State = {
		cx = cx,
		alive = alive,
		render = render,
		shown = shown,
		by_id = {},
		agents = {},
		open_ids = {},
		open_by_key = {},
		closed_by_key = {},
		open_by_idea = {},
		closed_by_idea = {},
		inflight = false,
		next_fetch = 0,
		query = "",
	}
	read_agents(s)
	tern.timer(0, function()
		tick(s)
	end)
	return s
end

-- The tab was opened: refresh the list unless it is a few seconds old.
function M.show(s: State)
	if not s.updated or os.time() - s.updated >= 3 then
		fetch(s)
	end
end

-- Open panes plus recent sessions, for the tab's label.
function M.count(s: State): number
	local closed = 0
	for _, session in s.sessions or {} do
		if not s.open_ids[session.id] then
			closed += 1
		end
	end
	return #s.agents + closed
end

function M.view(s: State): { any }
	local out: { any } = { toolbar(s) }
	if s.error then
		table.insert(out, ui.text(ui.span(s.error, "error")))
	end
	if not s.sessions and not s.error then
		table.insert(out, ui.progress(nil, "Loading sessions…"))
		return out
	end
	table.insert(out, search_box(s))
	local query = string.lower(s.query)
	local open, recent = {}, {}
	for _, a in s.agents do
		if hit(a.haystack, query) then
			open_rows(a, open)
		end
	end
	for _, session in s.sessions or {} do
		if not s.open_ids[session.id] and hit(session.haystack, query) then
			recent_rows(session, recent)
		end
	end
	local nomatch = "Nothing matches “" .. s.query .. "”"
	table.insert(out, ui.rule("Open"))
	table.insert(
		out,
		keyed(
			ui.table({
				{ id = "state", head = "", priority = 6 },
				{ id = "keys", head = "Keys", mono = true, priority = 5 },
				{ id = "title", head = "Session", grow = 1, truncate = "end", priority = 7 },
				{ id = "age", head = "", priority = 4 },
				{ id = "jump", head = "", priority = 3 },
			}, open, { selectable = true, selected = s.selected, empty = if query == "" then "No omp pane is open" else nomatch }),
			"sessions-open"
		)
	)
	table.insert(out, ui.rule("Recent"))
	table.insert(
		out,
		keyed(
			ui.table({
				{ id = "keys", head = "Keys", mono = true, priority = 5 },
				{ id = "title", head = "Session", grow = 1, truncate = "end", priority = 7 },
				{ id = "age", head = "", priority = 4 },
				{ id = "resume", head = "", priority = 3 },
			}, recent, {
				selectable = true,
				selected = s.selected,
				empty = if query ~= "" then nomatch elseif s.sessions then "No other omp session in the last 30 days" else "",
			}),
			"sessions-recent"
		)
	)
	return out
end

-- Type-to-filter: typed text and pastes extend the query, Backspace drops a character, Escape clears it.
function M.key(s: State, key: any): boolean
	if key.ctrl or key.meta or key.alt then
		return false
	end
	if key.name == "escape" or key.name == "backspace" then
		if s.query == "" then
			return false
		end
		s.query = if key.name == "escape" then "" else string.sub(s.query, 1, (utf8.offset(s.query, -1) or 1) - 1)
		return true
	end
	if type(key.text) == "string" and key.text ~= "" then
		s.query ..= (string.gsub(key.text, "%c", " "))
		return true
	end
	return false
end

-- Handles the tab's events; false for anyone else's.
function M.event(s: State, ev: any): boolean
	if ev.ev == "action" and ev.act == "sessions_refresh" then
		fetch(s)
		return true
	end
	if not TABLES[ev.id] then
		return false
	end
	local item = ev.item
	if type(item) ~= "string" then
		return true
	end
	if ev.ev == "select" then
		s.selected = item
		return true
	end
	local go = ev.ev == "activate" or (ev.ev == "action" and (ev.act == "jump" or ev.act == "resume" or ev.act == "Jump to pane" or ev.act == "Resume"))
	if not go then
		return true
	end
	local pane = tonumber(string.match(item, "^open2?:(%d+)$"))
	if pane then
		for _, a in s.agents do
			if a.pane == pane then
				M.jump(s, a)
			end
		end
		return true
	end
	local id = string.match(item, "^[sr]:(.+)$")
	local session = id and s.by_id[id]
	if session then
		M.resume(s, session)
	end
	return true
end

return M
