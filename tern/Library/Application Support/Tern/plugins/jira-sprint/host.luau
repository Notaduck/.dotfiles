-- Work: one block with three tabs, Sprint, Ideas and Sessions, which window.luau pins to the right edge of the
-- shown tab.
--
-- Sprint: your issues in the open sprints, sub-tasks nested under their parent. Typing filters the list;
-- a row click opens the issue in the default browser. A duck or a capybara roams the dock.
-- Implement (button or right-click) opens `jira-sprint://implement/<KEY>`; window.luau claims that link, makes a
-- worktree on `feature/<KEY>_<slug>` and starts omp there with `/implement <KEY>`. The issue is never changed.
--
-- Ideas: ideas.luau, the ~/ideas store. Sessions: sessions.luau, the omp sessions, open and recent. Sprint and
-- Ideas rows mark an issue or idea with an omp session (● open, ○ to resume) and offer it in their row menu.
--
-- jira.json in the plugin's data folder, written with defaults on first use:
--   site    Jira Cloud base URL
--   email   Atlassian account; its API token lives in the login keychain under KEYCHAIN_SERVICE
--   jql     which issues to list
--   repos        name -> { path, base, labels, summaryPrefixes } for Implement (window.luau): an issue label equal
--                to the name or in `labels` wins, then a summary starting with a prefix
--   defaultRepo  the repos entry Implement uses when no rule matches

local Ideas = require("./ideas")
local Pet = require("./pet")
local Sessions = require("./sessions")

local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local CONFIG = tern.plugin.data .. "/jira.json"
local KEYCHAIN_SERVICE = "tern-jira-sprint"
local KEYCHAIN_NOT_FOUND = 44
local TOKEN_URL = "https://id.atlassian.com/manage-profile/security/api-tokens"
local SPRINT_FIELD_SCHEMA = "com.pyxis.greenhopper.jira:gh-sprint"
local MAX_RESULTS = 100
local HTTP_TIMEOUT_MS = 20000
local REFRESH_S = 300
local TICK_MS = 15000
local CATEGORY_ORDER = { indeterminate = 1, new = 2, done = 3 }
local CATEGORY_TONE = { indeterminate = "warning", new = "info", done = "success" }
local TABS = { "sprint", "ideas", "sessions" }
-- The shown tab, shared with window.luau (its ctrl+b shift+i toggles on it) and a new block's default.
local TAB_KEY = "tab"
local DEFAULT_CONFIG = [[
{
  "site": "https://your-site.atlassian.net",
  "email": "you@example.com",
  "jql": "assignee = currentUser() AND sprint in openSprints() ORDER BY Rank ASC",
  "repos": {
    "Backend": { "path": "~/projects/backend", "base": "origin/develop", "labels": ["Backend"], "summaryPrefixes": ["[BE]"] }
  },
  "defaultRepo": "Backend"
}
]]

local ui = tern.ui

type Config = { site: string, email: string, jql: string }
type Issue = {
	key: string,
	summary: string,
	status: string,
	category: string,
	kind: string,
	labels: { string },
	parent: string?,
	order: number,
	-- Sub-tasks, from the issue's own `subtasks` field: all of them, assigned to you or not.
	children: { Issue },
}
type Sprint = { name: string, ends: number? }
type State = {
	cx: any,
	alive: boolean,
	config: Config?,
	sprint_field: string?,
	issues: { Issue }?,
	index: { [string]: Issue },
	query: string,
	animal: string,
	pet: Pet.Pet,
	sprints: { Sprint },
	more: boolean,
	error: string?,
	needs_token: boolean,
	inflight: boolean,
	updated: number?,
	next_fetch: number,
	tab: string,
	ideas: Ideas.State,
	sessions: Sessions.State,
}

-- Time --------------------------------------------------------------------------------------------

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

-- ISO 8601 UTC timestamps as Jira returns sprint dates ("2026-11-12T10:00:00.000Z").
local function parse_time(s: string?): number?
	if not s then
		return nil
	end
	local y, mo, d, h, mi, sec = string.match(s, "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	return days_from_civil(tonumber(y) :: number, tonumber(mo) :: number, tonumber(d) :: number) * 86400
		+ (tonumber(h) :: number) * 3600
		+ (tonumber(mi) :: number) * 60
		+ (tonumber(sec) :: number)
end

local function ago(t: number?): string
	if not t then
		return ""
	end
	local d = os.time() - t
	if d < 60 then
		return "just now"
	elseif d < 3600 then
		return string.format("%dm ago", d // 60)
	end
	return string.format("%dh ago", d // 3600)
end

local function ends_in(t: number): string
	local d = t - os.time()
	if d <= 0 then
		return "ended"
	elseif d < 86400 then
		return string.format("ends in %dh", d // 3600)
	end
	return string.format("ends in %dd", d // 86400)
end

-- Config ------------------------------------------------------------------------------------------

local function load_config(): (Config?, string?)
	if not tern.fs.exists(CONFIG) then
		tern.fs.mkdir(tern.plugin.data)
		tern.fs.write(CONFIG, DEFAULT_CONFIG)
	end
	local ok, cfg = pcall(function()
		return tern.json.decode(tern.fs.read(CONFIG))
	end)
	if not ok or type(cfg) ~= "table" then
		return nil, "jira.json doesn't parse: " .. tostring(cfg)
	end
	for _, k in { "site", "email", "jql" } do
		if type(cfg[k]) ~= "string" or cfg[k] == "" then
			return nil, string.format("jira.json needs a non-empty \"%s\" string", k)
		end
	end
	return {
		site = (string.gsub(cfg.site, "/+$", "")),
		email = cfg.email,
		jql = cfg.jql,
	}, nil
end

-- Processes and HTTP ------------------------------------------------------------------------------

type Run = { status: number, stdout: string, stderr: string, timed_out: boolean }

local function run(argv: { string }, timeout_ms: number, cb: (Run) -> (), stdin: string?)
	local opts = { env = { PATH = PATH }, timeout_ms = timeout_ms, stdin = stdin }
	local ok, err = pcall(tern.process.run, argv, opts, cb)
	if not ok then
		cb({ status = -1, stdout = "", stderr = tostring(err), timed_out = false })
	end
end

local function first_line(s: string): string
	local line = string.match(s, "[^\r\n]+") or s
	return (string.gsub(line, "^%s+", ""))
end

-- The token, nil without an error when the keychain has none for `email`.
local function read_token(email: string, cb: (string?, string?) -> ())
	run({ "security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", email, "-w" }, 10000, function(r)
		if r.status == KEYCHAIN_NOT_FOUND then
			cb(nil, nil)
			return
		end
		local token = if r.status == 0 then string.match(r.stdout, "^%s*(.-)%s*$") else nil
		if not token or token == "" then
			cb(nil, "Keychain: " .. (if r.timed_out then "security timed out" else first_line(r.stderr)))
			return
		end
		cb(token, nil)
	end)
end

-- Stores the clipboard as the token. `security -i` reads the command from stdin: the token stays out of
-- argv, and the interactive `-w` prompt would cut it at 128 characters.
local function save_token(email: string, cb: (string?) -> ())
	run({ "pbpaste" }, 5000, function(clip)
		local token = string.match(clip.stdout, "^%s*(.-)%s*$") or ""
		if clip.status ~= 0 or not string.match(token, "^[%w_=%-]+$") then
			cb("The clipboard doesn't hold an API token")
			return
		end
		local command = string.format("add-generic-password -U -s %s -a \"%s\" -w \"%s\"\n", KEYCHAIN_SERVICE, email, token)
		run({ "security", "-i" }, 10000, function(r)
			local err = first_line(r.stderr)
			cb(if r.status ~= 0 or err ~= "" then "Keychain: " .. err else nil)
		end, command)
	end)
end

local function jira_message(body: string): string
	local ok, v = pcall(tern.json.decode, body)
	if ok and type(v) == "table" and type(v.errorMessages) == "table" and type(v.errorMessages[1]) == "string" then
		return v.errorMessages[1]
	end
	return string.sub(first_line(body), 1, 200)
end

-- `cb`'s third argument is true when Jira rejected the credentials.
local function jira(cfg: Config, token: string, method: string, path: string, body: string?, cb: (any?, string?, boolean?) -> ())
	local headers: { [string]: string } = {
		Authorization = "Basic " .. tern.base64.encode(cfg.email .. ":" .. token),
		Accept = "application/json",
	}
	if body then
		headers["Content-Type"] = "application/json"
	end
	local opts = { method = method, headers = headers, body = body, timeout_ms = HTTP_TIMEOUT_MS }
	local ok, err = pcall(tern.fetch, cfg.site .. path, opts, function(res)
		if res.error then
			cb(nil, if res.timed_out then "Jira timed out" else res.error)
		elseif res.status == 401 or res.status == 403 then
			cb(nil, string.format("Jira rejected the API token for %s (HTTP %d)", cfg.email, res.status), true)
		elseif res.status < 200 or res.status >= 300 then
			cb(nil, string.format("Jira answered HTTP %d: %s", res.status, jira_message(res.body)))
		else
			local okj, v = pcall(tern.json.decode, res.body)
			if okj then
				cb(v, nil)
			else
				cb(nil, "Jira returned invalid JSON")
			end
		end
	end)
	if not ok then
		cb(nil, tostring(err))
	end
end

-- State -------------------------------------------------------------------------------------------

local function render(s: State)
	if s.alive then
		local ok = pcall(function()
			s.cx:render()
		end)
		if not ok then
			s.alive = false
		end
	end
end

local function pane_alive(s: State): boolean
	for _, p in tern.pane.list() do
		if p.pane == s.cx.pane then
			return true
		end
	end
	return false
end

local function finish(s: State, err: string?)
	s.error = err
	s.inflight = false
	s.updated = os.time()
	render(s)
end

local function to_issue(it: any, order: number, parent: string?): Issue
	local f = it.fields or {}
	local status = f.status or {}
	return {
		key = it.key,
		summary = f.summary or "",
		status = status.name or "?",
		category = status.statusCategory and status.statusCategory.key or "new",
		kind = f.issuetype and f.issuetype.name or "",
		labels = if type(f.labels) == "table" then f.labels else {},
		parent = parent or (f.parent and f.parent.key),
		order = order,
		children = {},
	}
end

-- Top-level issues with their sub-tasks nested; a sub-task the search returned next to its parent shows
-- only under it.
local function parse_issues(raw: { any }): ({ Issue }, { [string]: Issue })
	local listed: { [string]: boolean } = {}
	for _, it in raw do
		listed[it.key] = true
	end
	local out: { Issue } = {}
	local index: { [string]: Issue } = {}
	for i, it in raw do
		local f = it.fields or {}
		local nested = f.issuetype and f.issuetype.subtask and f.parent and listed[f.parent.key]
		if not nested then
			local issue = to_issue(it, i, nil)
			for j, sub in f.subtasks or {} do
				local child = to_issue(sub, j, issue.key)
				table.insert(issue.children, child)
				index[child.key] = child
			end
			table.insert(out, issue)
			index[issue.key] = issue
		end
	end
	table.sort(out, function(a, b)
		local ca, cb = CATEGORY_ORDER[a.category] or 2, CATEGORY_ORDER[b.category] or 2
		if ca ~= cb then
			return ca < cb
		end
		return a.order < b.order
	end)
	return out, index
end

-- Every active sprint the issues are in, soonest end first.
local function active_sprints(raw: { any }, field: string?): { Sprint }
	local out: { Sprint } = {}
	if not field then
		return out
	end
	local seen: { [string]: boolean } = {}
	for _, it in raw do
		local sprints = it.fields and it.fields[field]
		if type(sprints) == "table" then
			for _, sp in sprints do
				if type(sp) == "table" and sp.state == "active" and type(sp.name) == "string" and not seen[sp.name] then
					seen[sp.name] = true
					table.insert(out, { name = sp.name, ends = parse_time(sp.endDate) })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.ends or math.huge) < (b.ends or math.huge)
	end)
	return out
end

-- The id of the Sprint custom field, looked up once; nil when the site has none.
local function with_sprint_field(s: State, cfg: Config, token: string, cb: (string?) -> ())
	if s.sprint_field ~= nil then
		cb(if s.sprint_field == "" then nil else s.sprint_field)
		return
	end
	jira(cfg, token, "GET", "/rest/api/3/field", nil, function(fields, err)
		if err then
			finish(s, err)
			return
		end
		s.sprint_field = ""
		for _, f in fields do
			if f.schema and f.schema.custom == SPRINT_FIELD_SCHEMA then
				s.sprint_field = f.id
				break
			end
		end
		cb(if s.sprint_field == "" then nil else s.sprint_field)
	end)
end

local function search(s: State, cfg: Config, token: string, field: string?)
	local fields = tern.json.array({ "summary", "status", "issuetype", "parent", "subtasks", "labels" })
	if field then
		table.insert(fields, field)
	end
	local body = tern.json.encode({ jql = cfg.jql, fields = fields, maxResults = MAX_RESULTS })
	jira(cfg, token, "POST", "/rest/api/3/search/jql", body, function(v, err)
		if err then
			finish(s, err)
			return
		end
		local raw = v.issues or {}
		s.issues, s.index = parse_issues(raw)
		s.sprints = active_sprints(raw, field)
		s.more = type(v.nextPageToken) == "string"
		finish(s, nil)
	end)
end

local function fetch(s: State)
	if s.inflight then
		return
	end
	s.next_fetch = os.time() + REFRESH_S
	local cfg, cerr = load_config()
	s.config = cfg
	if not cfg then
		finish(s, cerr)
		return
	end
	s.inflight = true
	render(s)
	read_token(cfg.email, function(token, terr)
		if not token then
			s.needs_token = terr == nil
			finish(s, terr)
			return
		end
		-- search/jql answers a rejected token as anonymous (200, no issues), so check the token first.
		jira(cfg, token, "GET", "/rest/api/3/myself", nil, function(_, err, rejected)
			s.needs_token = rejected == true
			if err then
				finish(s, err)
				return
			end
			with_sprint_field(s, cfg, token, function(field)
				search(s, cfg, token, field)
			end)
		end)
	end)
end

local function tick(s: State)
	if not s.alive then
		return
	end
	if not pane_alive(s) then
		s.alive = false
		return
	end
	if os.time() >= s.next_fetch then
		fetch(s)
	else
		render(s)
	end
	tern.timer(TICK_MS, function()
		tick(s)
	end)
end

-- Actions -----------------------------------------------------------------------------------------

local function open_external(s: State, url: string)
	run({ "open", url }, 10000, function(r)
		if r.status ~= 0 then
			s.cx:toast("error", "Couldn't open " .. url, first_line(r.stderr))
		end
	end)
end

local function browse_url(cfg: Config, key: string): string
	return cfg.site .. "/browse/" .. key
end

local function url_encode(s: string): string
	return (string.gsub(s, "[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

-- Plugin blocks run on the host, where `cx.agents` doesn't exist: the window half claims this link and starts omp.
local function implement(s: State, cx: any, key: string)
	local issue = s.index[key]
	if not issue then
		s.cx:toast("error", "Unknown issue " .. key)
		return
	end
	cx:open(
		string.format(
			"jira-sprint://implement/%s?summary=%s&labels=%s",
			key,
			url_encode(issue.summary),
			url_encode(table.concat(issue.labels, ","))
		)
	)
end

-- Pet (pet.luau) ----------------------------------------------------------------------------------

local function animate(s: State)
	if not s.alive then
		return
	end
	if s.animal ~= "off" then
		Pet.step(s.pet, s.animal, s.cx.cols or 40)
		render(s)
	end
	tern.timer(Pet.TICK_MS, function()
		animate(s)
	end)
end

-- View --------------------------------------------------------------------------------------------

local function keyed(node: any, key: string)
	node.p = node.p or {}
	node.p.key = key
	return node
end

-- Segmented Sprint | Ideas | Sessions strip with counts.
local function tab_strip(s: State): any
	local issues = 0
	for _, issue in s.issues or {} do
		issues += 1 + #issue.children
	end
	local labels = {
		sprint = if s.issues then string.format("Sprint %d", issues) else "Sprint",
		ideas = string.format("Ideas %d", Ideas.count(s.ideas)),
		sessions = string.format("Sessions %d", Sessions.count(s.sessions)),
	}
	local items = {}
	for _, t in TABS do
		table.insert(items, ui.button(labels[t], { actions = { click = "tab=" .. t }, size = "sm", on = t == s.tab }))
	end
	return keyed(ui.row(items), "tabs")
end

local function set_tab(s: State, tab: string)
	if table.find(TABS, tab) then
		s.tab = tab
		tern.kv.set(TAB_KEY, tab)
		if tab == "sessions" then
			Sessions.show(s.sessions)
		end
	end
end

local function toolbar(s: State): any
	local status = if s.inflight then "querying…" elseif s.updated then "updated " .. ago(s.updated) else ""
	local items = {
		ui.button("Refresh", { actions = { click = "refresh" }, size = "sm", icon = "refresh", busy = s.inflight }),
		ui.button("Settings", { actions = { click = "edit_config" }, size = "sm", icon = "doc" }),
		ui.text(ui.span(status, "muted")),
	}
	for _, a in Pet.ANIMALS do
		table.insert(items, ui.button(Pet.LABEL[a], { actions = { click = "animal=" .. a }, size = "sm", on = a == s.animal }))
	end
	return ui.row(items)
end

local function search_box(s: State): any
	local cursor = utf8.len(s.query) or #s.query
	local placeholder = "Type to search key, summary or status · Esc clears"
	return keyed(ui.node("input", { text = s.query, cursor = cursor, placeholder = placeholder }), "search")
end

-- Type-to-search: typed text and pastes extend the query, Backspace drops a character, Escape clears it.
local function search_key(s: State, key: any): boolean
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

local function sprint_line(s: State): any
	local spans: { any } = {}
	if #s.sprints == 0 then
		table.insert(spans, ui.span("Open sprint", "strong"))
	end
	for i, sprint in s.sprints do
		if i > 1 then
			table.insert(spans, ui.span("  ·  ", "muted"))
		end
		table.insert(spans, ui.span(sprint.name, "strong"))
		if sprint.ends then
			table.insert(spans, ui.span(" " .. ends_in(sprint.ends), "muted"))
		end
	end
	local n, subs = 0, 0
	for _, issue in s.issues or {} do
		n += 1
		subs += #issue.children
	end
	table.insert(spans, ui.span(string.format(" · %d issue%s", n, if n == 1 then "" else "s"), "muted"))
	if subs > 0 then
		table.insert(spans, ui.span(string.format(" · %d sub-task%s", subs, if subs == 1 then "" else "s"), "muted"))
	end
	if s.more then
		table.insert(spans, ui.span(string.format(" (first %d)", MAX_RESULTS), "warning"))
	end
	return ui.text(spans)
end

local function token_view(s: State): any
	local email = if s.config then s.config.email else "you@example.com"
	return ui.card("Jira API token", {
		ui.text("1. Create an API token for " .. email .. " in your Atlassian account and copy it."),
		ui.row({ ui.button("Create token", { actions = { click = "create_token" }, size = "sm" }) }),
		ui.text("2. Save it from the clipboard into the login keychain."),
		ui.row({ ui.button("Save token from clipboard", { actions = { click = "save_token" }, size = "sm", variant = "primary" }) }),
	}, { icon = "list" })
end

local function matches(issue: Issue, query: string): boolean
	if query == "" then
		return true
	end
	local text = string.lower(issue.key .. " " .. issue.summary .. " " .. issue.status)
	return string.find(text, query, 1, true) ~= nil
end

local function issue_row(s: State, issue: Issue, child: boolean): any
	local summary: { any } = { ui.span(issue.summary) }
	if #issue.children > 0 then
		local finished = 0
		for _, c in issue.children do
			if c.category == "done" then
				finished += 1
			end
		end
		table.insert(summary, ui.span(string.format("  %d/%d sub-tasks done", finished, #issue.children), "muted"))
	elseif issue.parent and not child then
		table.insert(summary, ui.span("  " .. issue.parent, "muted"))
	end
	local link = Sessions.find(s.sessions, { issue.key })
	local menu = { "Implement", "Open in browser" }
	Sessions.menu(link, menu)
	local key: { any } = { if child then ui.span("↳ " .. issue.key) else ui.span(issue.key, "strong") }
	local marker = Sessions.marker(link)
	if marker then
		table.insert(key, marker)
	end
	return {
		id = issue.key,
		title = "Open " .. issue.key .. " in the browser"
			.. (if link and link.open then " · omp session open" elseif link then " · omp session to resume" else ""),
		menu = menu,
		cells = {
			key,
			ui.span(issue.kind, "muted"),
			summary,
			{ badge = { text = issue.status, tone = CATEGORY_TONE[issue.category] or "muted" } },
			{ button = { text = "Implement", act = "implement", variant = "quiet" } },
		},
	}
end

-- Parents with their sub-tasks under them. A search keeps a parent that matches (with every sub-task)
-- or that has a matching sub-task (with only those).
local function issues_table(s: State): any
	local query = string.lower(s.query)
	local rows = {}
	for _, issue in s.issues or {} do
		local own = matches(issue, query)
		local kids = {}
		for _, c in issue.children do
			if own or matches(c, query) then
				table.insert(kids, c)
			end
		end
		if own or #kids > 0 then
			table.insert(rows, issue_row(s, issue, false))
			for _, c in kids do
				table.insert(rows, issue_row(s, c, true))
			end
		end
	end
	local empty = if query == "" then "Nothing assigned to you in the open sprint" else "No issue matches “" .. s.query .. "”"
	return keyed(
		ui.table({
			{ id = "key", head = "Key", mono = true, priority = 5 },
			{ id = "type", head = "Type", priority = 1 },
			{ id = "summary", head = "Summary", grow = 1, truncate = "end", priority = 4 },
			{ id = "status", head = "Status", priority = 2 },
			{ id = "implement", head = "", priority = 3 },
		}, rows, { selectable = true, empty = empty }),
		"issues"
	)
end

-- Block -------------------------------------------------------------------------------------------

tern.block.define("sprint", {
	font = "sans",

	-- `args[1]` ("sprint", "ideas" or "sessions", from window.luau) picks the tab; else the saved one, else the last used.
	init = function(cx, args, saved)
		local animal = if saved and Pet.valid(saved.animal) then saved.animal else "duck"
		local tab = args and args[1]
		if not table.find(TABS, tab) then
			tab = if saved and table.find(TABS, saved.tab) then saved.tab else tern.kv.get(TAB_KEY)
		end
		local s: State
		s = {
			cx = cx,
			alive = true,
			index = {},
			query = "",
			sprints = {},
			animal = animal,
			pet = Pet.new(),
			more = false,
			needs_token = false,
			inflight = false,
			next_fetch = 0,
			tab = "sprint",
			ideas = nil :: any,
			sessions = Sessions.new(cx, function()
				return s.alive
			end, function()
				render(s)
			end, function()
				return s.tab == "sessions"
			end),
		}
		s.ideas = Ideas.new(cx, function()
			return s.alive
		end, function()
			render(s)
		end, s.sessions)
		set_tab(s, if table.find(TABS, tab) then tab else "sprint")
		tern.timer(0, function()
			tick(s)
			animate(s)
		end)
		return s
	end,

	title = function(s)
		if s.tab == "ideas" then
			return "Ideas"
		elseif s.tab == "sessions" then
			return "omp sessions"
		end
		return if #s.sprints == 1 then "Jira · " .. s.sprints[1].name else "Jira Sprint"
	end,

	save = function(s)
		return { animal = s.animal, tab = s.tab }
	end,

	view = function(s, _cx)
		local children = { tab_strip(s) }
		if s.tab == "ideas" then
			for _, node in Ideas.view(s.ideas) do
				table.insert(children, node)
			end
		elseif s.tab == "sessions" then
			for _, node in Sessions.view(s.sessions) do
				table.insert(children, node)
			end
		else
			table.insert(children, toolbar(s))
			if s.error then
				table.insert(children, ui.text(ui.span(s.error, "error")))
			end
			if s.needs_token then
				table.insert(children, token_view(s))
			elseif s.issues then
				table.insert(children, sprint_line(s))
				table.insert(children, search_box(s))
				table.insert(children, issues_table(s))
			elseif s.inflight then
				table.insert(children, ui.progress(nil, "Loading sprint…"))
			end
		end
		return { main = ui.col(children), dock = if s.animal ~= "off" then Pet.view(s.pet, s.animal) else nil }
	end,

	-- Typing filters the shown tab.
	key = function(s, key, _cx)
		if s.tab == "ideas" then
			return Ideas.key(s.ideas, key)
		elseif s.tab == "sessions" then
			return Sessions.key(s.sessions, key)
		end
		return search_key(s, key)
	end,

	event = function(s, ev, cx)
		if Ideas.event(s.ideas, ev) or Sessions.event(s.sessions, ev) then
			return
		end
		if ev.ev == "action" then
			-- Tab clicks arrive split ("tab" with a value); window.luau's switch sends "tab=<tab>" whole.
			local tab = if ev.act == "tab" then ev.value
				elseif type(ev.act) == "string" then string.match(ev.act, "^tab=(%a+)$")
				else nil
			if tab then
				set_tab(s, tab)
				cx:save()
			elseif ev.act == "refresh" then
				fetch(s)
			elseif ev.act == "edit_config" then
				load_config()
				cx:open(CONFIG)
			elseif ev.act == "create_token" then
				open_external(s, TOKEN_URL)
			elseif ev.act == "save_token" and s.config then
				save_token(s.config.email, function(err)
					if err then
						s.cx:toast("error", "Token not saved", err)
						return
					end
					s.cx:toast("success", "Token saved", "Checking it with Jira")
					fetch(s)
				end)
			elseif ev.act == "animal" and Pet.valid(ev.value) then
				s.animal = ev.value
				cx:save()
			elseif (ev.act == "implement" or ev.act == "Implement") and ev.item then
				implement(s, cx, ev.item)
			elseif ev.act == "Open in browser" and ev.item and s.config then
				open_external(s, browse_url(s.config, ev.item))
			elseif ev.id == "main.issues" and type(ev.item) == "string" and type(ev.act) == "string" then
				Sessions.act(s.sessions, Sessions.find(s.sessions, { ev.item }), ev.act)
			end
		elseif (ev.ev == "select" or ev.ev == "activate") and ev.id == "main.issues" and ev.item and s.config then
			open_external(s, browse_url(s.config, ev.item))
		end
	end,
})
