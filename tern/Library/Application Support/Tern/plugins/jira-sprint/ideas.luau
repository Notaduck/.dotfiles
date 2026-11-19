-- The Ideas tab of the Work block: the ideas in ~/ideas/index.json (written by the omp `ideas` extension), the
-- focused pane's project first, then the rest and the inbox. Typing filters; a row's Load button, double-click
-- or Enter loads the idea into a chat, and its right-click menu holds the rest.
--
-- It only reads the store; every write goes through the `ideas` CLI. Loading needs `cx.agents`, which only
-- the window half has, so the block opens `ideas://load/<id>` and `ideas://new/<id>` links that window.luau
-- claims (sidebar.luau). A row whose idea has an omp session (its `sessions`, its Jira key or a session that
-- worked on it; sessions.luau) shows ● (open) or ○ (to resume) and offers it in its menu.

local Sessions = require("./sessions")

local HOME = tern.getenv("HOME") or ""
local ROOT = HOME .. "/ideas"
local INDEX = ROOT .. "/index.json"
local INBOX = ROOT .. "/inbox.md"
local CLI = HOME .. "/.local/bin/ideas"
local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local MAX_INDEX_BYTES = 4 * 1024 * 1024
local CLI_TIMEOUT_MS = 20000
local TICK_MS = 3000
-- Published by the window half: the working directory of the last focused pane that isn't this block.
local FOCUS_CWD_KEY = "focus-cwd"
local TABLES = { ["main.here"] = true, ["main.other"] = true, ["main.inbox"] = true }
local STATUSES = { "seed", "parked", "shaping", "ready", "promoted", "dropped" }
local STATUS_TONE = {
	seed = "muted",
	parked = "info",
	shaping = "warning",
	ready = "success",
	promoted = "success",
	dropped = "muted",
}

local ui = tern.ui

export type Idea = {
	id: string,
	title: string,
	status: string,
	tags: { string },
	project: string?,
	jira: string?,
	updated: string?,
	dir: string,
	artifacts: { string },
	sessions: { string },
}
type InboxLine = { line: number, date: string?, text: string }
export type State = {
	cx: any,
	-- The block's: whether it still lives, and a re-render.
	alive: () -> boolean,
	render: () -> (),
	sessions: Sessions.State,
	missing: boolean,
	reindexed: boolean,
	rev: string?,
	ideas: { Idea },
	by_id: { [string]: Idea },
	inbox: { InboxLine },
	error: string?,
	query: string,
	selected: string?,
	focus_cwd: string?,
}

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

local function basename(p: string): string
	return string.match(p, "([^/]+)/*$") or p
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

-- "2026-11-17" as an age from today: "today", "3d", "2w", "4mo".
local function age(date: string?): string
	local y, m, d = string.match(date or "", "^(%d+)-(%d+)-(%d+)")
	if not y then
		return ""
	end
	local now = os.date("*t") :: any
	local days = days_from_civil(now.year, now.month, now.day)
		- days_from_civil(tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number)
	if days <= 0 then
		return "today"
	elseif days < 14 then
		return days .. "d"
	elseif days < 60 then
		return (days // 7) .. "w"
	end
	return (days // 30) .. "mo"
end

-- Whether `cwd` is `project` or inside it.
local function within(cwd: string?, project: string?): boolean
	if not cwd or not project then
		return false
	end
	local root = string.gsub(project, "/+$", "")
	return cwd == root or string.sub(cwd, 1, #root + 1) == root .. "/"
end

-- Store -------------------------------------------------------------------------------------------

type Run = { status: number, stdout: string, stderr: string, timed_out: boolean }

-- Runs the ideas CLI; IDEAS_DIR pins it to the store this tab reads.
local function ideas_cli(args: { string }, cb: (Run) -> ())
	local argv = { CLI }
	for _, a in args do
		table.insert(argv, a)
	end
	local opts = { env = { PATH = PATH, IDEAS_DIR = ROOT }, timeout_ms = CLI_TIMEOUT_MS }
	local ok, err = pcall(tern.process.run, argv, opts, cb)
	if not ok then
		cb({ status = -1, stdout = "", stderr = tostring(err), timed_out = false })
	end
end

local function cli_error(r: Run): string
	if r.timed_out then
		return "the ideas CLI timed out"
	end
	local msg = first_line(r.stderr)
	return if msg ~= "" then msg else "exit status " .. r.status
end

local function parse_index(s: State, v: any)
	local ideas: { Idea } = {}
	local by_id: { [string]: Idea } = {}
	for _, e in (if type(v.ideas) == "table" then v.ideas else {}) do
		local id = str(e.id)
		if id then
			local idea: Idea = {
				id = id,
				title = str(e.title) or id,
				status = str(e.status) or "seed",
				tags = strings(e.tags),
				project = str(e.project),
				jira = str(e.jira),
				updated = str(e.updated) or str(e.created),
				dir = str(e.dir) or id,
				artifacts = strings(e.artifacts),
				sessions = strings(e.sessions),
			}
			table.insert(ideas, idea)
			by_id[id] = idea
		end
	end
	local inbox: { InboxLine } = {}
	for _, e in (if type(v.inbox) == "table" then v.inbox else {}) do
		if type(e) == "table" and str(e.text) then
			table.insert(inbox, { line = tonumber(e.line) or 0, date = str(e.date), text = e.text })
		end
	end
	s.ideas, s.by_id, s.inbox = ideas, by_id, inbox
end

local load_index: (s: State, force: boolean?) -> boolean

-- Rebuilds a missing index.json once per block, then reads it again.
local function reindex(s: State)
	s.reindexed = true
	ideas_cli({ "reindex" }, function(r)
		if r.status ~= 0 then
			s.error = "ideas reindex failed: " .. cli_error(r)
		else
			load_index(s, true)
		end
		s.render()
	end)
end

-- Reads index.json; true when what the tab shows changed. An unchanged `rev` skips the decode.
function load_index(s: State, force: boolean?): boolean
	if not tern.fs.exists(ROOT) then
		local changed = not s.missing
		s.missing, s.rev, s.ideas, s.by_id, s.inbox, s.error = true, nil, {}, {}, {}, nil
		return changed
	end
	local was_missing = s.missing
	s.missing = false
	if not tern.fs.exists(INDEX) then
		if not s.reindexed then
			reindex(s)
		end
		return was_missing
	end
	local ok, raw = pcall(tern.fs.read, INDEX, MAX_INDEX_BYTES)
	if not ok then
		local err = "Can't read index.json: " .. tostring(raw)
		local changed = s.error ~= err
		s.error = err
		return changed
	end
	local rev = string.match(raw, '"rev"%s*:%s*(%d+)')
	if not force and not was_missing and rev ~= nil and rev == s.rev and s.error == nil then
		return false
	end
	local okj, v = pcall(tern.json.decode, raw)
	if not okj or type(v) ~= "table" then
		s.error = "index.json doesn't parse: " .. tostring(v)
		return true
	end
	parse_index(s, v)
	s.rev, s.error = rev, nil
	return true
end

local function read_focus_cwd(s: State): boolean
	local ok, cwd = pcall(tern.kv.get, FOCUS_CWD_KEY)
	cwd = if ok then str(cwd) else nil
	if cwd == s.focus_cwd then
		return false
	end
	s.focus_cwd = cwd
	return true
end

local function tick(s: State)
	if not s.alive() then
		return
	end
	local changed = load_index(s)
	if read_focus_cwd(s) then
		changed = true
	end
	if changed then
		s.render()
	end
	tern.timer(TICK_MS, function()
		tick(s)
	end)
end

-- Actions -----------------------------------------------------------------------------------------

local function link(kind: string, idea: Idea): string
	local url = "ideas://" .. kind .. "/" .. url_encode(idea.id)
	if idea.project then
		url ..= "?project=" .. url_encode(idea.project)
	end
	return url
end

local function implement_url(idea: Idea): string
	local url = "jira-sprint://implement/" .. url_encode(idea.jira or "") .. "?summary=" .. url_encode(idea.title)
	if idea.project then
		url ..= "&repo=" .. url_encode(idea.project)
	end
	return url
end

local function set_status(s: State, idea: Idea, status: string)
	ideas_cli({ "status", idea.id, status }, function(r)
		if r.status ~= 0 then
			s.cx:toast("error", "Couldn't set " .. idea.id .. " to " .. status, cli_error(r))
		end
		load_index(s, true)
		s.render()
	end)
end

local function session_link(s: State, idea: Idea): Sessions.Link?
	return Sessions.find(s.sessions, if idea.jira then { idea.jira } else nil, idea.sessions, idea.id)
end

local function idea_menu(s: State, idea: Idea): { string }
	local menu = { "Load into this chat", "New chat" }
	Sessions.menu(session_link(s, idea), menu)
	table.insert(menu, "Open idea.md")
	table.insert(menu, "Open folder")
	for _, a in idea.artifacts do
		table.insert(menu, "Open " .. a)
	end
	if idea.jira then
		table.insert(menu, "Implement " .. idea.jira)
	end
	for _, st in STATUSES do
		if st ~= idea.status then
			table.insert(menu, "Status: " .. st)
		end
	end
	return menu
end

local function idea_action(s: State, idea: Idea, act: string)
	local dir = ROOT .. "/" .. idea.dir
	if act == "load" or act == "Load into this chat" then
		s.cx:open(link("load", idea))
	elseif act == "New chat" then
		s.cx:open(link("new", idea))
	elseif act == "Open idea.md" then
		s.cx:open(dir .. "/idea.md")
	elseif act == "Open folder" then
		s.cx:open(dir)
	elseif Sessions.act(s.sessions, session_link(s, idea), act) then
		return
	elseif idea.jira and act == "Implement " .. idea.jira then
		s.cx:open(implement_url(idea))
	elseif string.sub(act, 1, 8) == "Status: " then
		local status = string.sub(act, 9)
		if table.find(STATUSES, status) then
			set_status(s, idea, status)
		end
	elseif string.sub(act, 1, 5) == "Open " then
		local name = string.sub(act, 6)
		if table.find(idea.artifacts, name) then
			s.cx:open(dir .. "/artifacts/" .. name)
		end
	end
end

-- View --------------------------------------------------------------------------------------------

local function keyed(node: any, key: string)
	node.p = node.p or {}
	node.p.key = key
	return node
end

local function search_box(s: State): any
	local cursor = utf8.len(s.query) or #s.query
	local placeholder = "Type to filter title, tag, id or Jira key · Esc clears"
	return keyed(ui.node("input", { text = s.query, cursor = cursor, placeholder = placeholder }), "ideas-search")
end

local function matches(idea: Idea, query: string): boolean
	if query == "" then
		return true
	end
	local text = string.lower(table.concat({ idea.title, idea.id, idea.jira or "", table.concat(idea.tags, " ") }, " "))
	return string.find(text, query, 1, true) ~= nil
end

local function idea_row(s: State, idea: Idea): any
	local dropped = idea.status == "dropped"
	local title: { any } = { ui.span(idea.title, if dropped then "muted" else "strong") }
	local marker = Sessions.marker(session_link(s, idea))
	if marker then
		table.insert(title, marker)
	end
	local meta = {}
	for _, t in idea.tags do
		table.insert(meta, "#" .. t)
	end
	local when = age(idea.updated)
	if when ~= "" then
		table.insert(meta, when)
	end
	if #meta > 0 then
		table.insert(title, ui.span("  " .. table.concat(meta, " "), "muted"))
	end
	return {
		id = idea.id,
		title = idea.id .. (if idea.project then " · " .. idea.project else ""),
		menu = idea_menu(s, idea),
		cells = {
			title,
			ui.span(idea.jira or "", "muted"),
			{ badge = { text = idea.status, tone = STATUS_TONE[idea.status] or "muted" } },
			{ button = { text = "Load", act = "load", variant = "quiet" } },
		},
	}
end

local function ideas_table(s: State, key: string, ideas: { Idea }, empty: string): any
	-- Dropped ideas go last; otherwise index order (newest update first).
	local live, dropped = {}, {}
	for _, idea in ideas do
		table.insert(if idea.status == "dropped" then dropped else live, idea_row(s, idea))
	end
	for _, row in dropped do
		table.insert(live, row)
	end
	return keyed(
		ui.table({
			{ id = "title", head = "Idea", grow = 1, truncate = "end", priority = 5 },
			{ id = "jira", head = "Jira", mono = true, priority = 1 },
			{ id = "status", head = "Status", priority = 3 },
			{ id = "load", head = "", priority = 4 },
		}, live, { selectable = true, selected = s.selected, empty = empty }),
		key
	)
end

local function inbox_table(s: State, lines: { InboxLine }): any
	local rows = {}
	for _, l in lines do
		table.insert(rows, {
			id = "inbox:" .. l.line,
			title = "inbox.md line " .. l.line,
			menu = { "Open inbox.md" },
			cells = { ui.span(l.text), ui.span(l.date or "", "muted") },
		})
	end
	return keyed(
		ui.table({
			{ id = "text", head = "Note", grow = 1, truncate = "end", priority = 5 },
			{ id = "date", head = "Date", mono = true, priority = 1 },
		}, rows, { selectable = true, selected = s.selected, empty = "Nothing in the inbox" }),
		"inbox"
	)
end

local function store_view(s: State): { any }
	local query = string.lower(s.query)
	local here, other = {}, {}
	local project: string? = nil
	for _, idea in s.ideas do
		if matches(idea, query) then
			if within(s.focus_cwd, idea.project) then
				table.insert(here, idea)
				project = project or idea.project
			else
				table.insert(other, idea)
			end
		end
	end
	local inbox = {}
	for _, l in s.inbox do
		if query == "" or string.find(string.lower(l.text), query, 1, true) then
			table.insert(inbox, l)
		end
	end
	local nomatch = if query == "" then "No ideas yet" else "No idea matches “" .. s.query .. "”"
	local out: { any } = { search_box(s) }
	if #here > 0 then
		table.insert(out, ui.rule(basename(project :: string)))
		table.insert(out, ideas_table(s, "here", here, nomatch))
	end
	if #other > 0 or #here == 0 then
		table.insert(out, ui.rule(if #here > 0 then "Other projects" else "Ideas"))
		table.insert(out, ideas_table(s, "other", other, nomatch))
	end
	table.insert(out, ui.rule("Inbox"))
	table.insert(out, inbox_table(s, inbox))
	return out
end

local function empty_view(): { any }
	return {
		ui.card("No ideas yet", {
			ui.text("There is no ~/ideas store yet."),
			ui.text({
				ui.span("In omp, run "),
				ui.span("/idea save", "mono"),
				ui.span(" to park a plan, or "),
				ui.span("/idea note <text>", "mono"),
				ui.span(" to jot a loose idea."),
			}),
		}, { icon = "list" }),
	}
end

-- API ---------------------------------------------------------------------------------------------

function M.new(cx: any, alive: () -> boolean, render: () -> (), sessions: Sessions.State): State
	local s: State = {
		cx = cx,
		alive = alive,
		render = render,
		sessions = sessions,
		missing = false,
		reindexed = false,
		ideas = {},
		by_id = {},
		inbox = {},
		query = "",
	}
	load_index(s)
	read_focus_cwd(s)
	tern.timer(TICK_MS, function()
		tick(s)
	end)
	return s
end

-- Ideas plus inbox notes, for the tab's label.
function M.count(s: State): number
	return #s.ideas + #s.inbox
end

-- The tab's nodes, under the block's tab strip.
function M.view(s: State): { any }
	local out: { any } = {}
	if s.error then
		table.insert(out, ui.text(ui.span(s.error, "error")))
	end
	for _, node in (if s.missing then empty_view() else store_view(s)) do
		table.insert(out, node)
	end
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

-- Handles an event from one of the tab's tables; false for anyone else's.
function M.event(s: State, ev: any): boolean
	if not TABLES[ev.id] then
		return false
	end
	local item = ev.item
	if type(item) ~= "string" then
		return true
	end
	if string.sub(item, 1, 6) == "inbox:" then
		if ev.ev == "select" then
			s.selected = item
		elseif ev.ev == "activate" or (ev.ev == "action" and ev.act == "Open inbox.md") then
			s.cx:open(INBOX)
		end
		return true
	end
	local idea = s.by_id[item]
	if not idea then
		return true
	end
	if ev.ev == "select" then
		s.selected = item
	elseif ev.ev == "activate" then
		idea_action(s, idea, "load")
	elseif ev.ev == "action" and type(ev.act) == "string" then
		idea_action(s, idea, ev.act)
	end
	return true
end

return M
