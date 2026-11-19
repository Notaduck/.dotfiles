-- Window half of Work (Jira Sprint + Ideas + Sessions): the sidebar commands, the Implement link, the ideas
-- links and the session links.
--
-- The Work block (host.luau) is a sidebar pinned to the right edge of the shown tab (sidebar.luau):
-- ctrl+b i toggles it on its last used tab; ctrl+b shift+i opens it on Ideas, or hides it when it shows Ideas.
-- `ideas://load|new/<id>` (from the Ideas tab) load an idea into an omp chat (sidebar.luau).
--
-- Sessions: while a Work block exists, the open omp panes go to tern.kv ("open-agents") for its Sessions tab
-- (sessions.luau). `work://session/jump/<pane>` focuses a pane, switching Tern session and unparking as
-- needed; `work://session/resume/<id>?cwd=…` opens a tab running `omp --resume <id>` in cwd (else HOME), or
-- jumps to the pane already running that session.
--
-- `jira-sprint://implement/<KEY>?summary=…&labels=a,b[&repo=/path]` (opened by the sprint block's Implement button,
-- or by the Ideas sidebar for a promoted idea) reuses a session first: it jumps to an open omp pane whose title
-- holds KEY or that runs in the worktree, else resumes the best `omp-sessions find KEY` match that has KEY among
-- its keys. Otherwise it picks the repository: `repo`; else the first "repos" entry in jira.json whose name or
-- `labels` matches an issue label; else one whose `summaryPrefixes` starts the summary (e.g. "[BE]"); else
-- "defaultRepo". It then reuses or creates the worktree `<repo>-worktrees/<KEY>` (or any worktree already on a
-- `feature/<KEY>_…` branch) on `feature/<KEY>_<camelSlug>` (off "base", default
-- origin/develop, without upstream tracking), and starts omp there with `/implement <KEY>`.
-- Nothing is written to Jira.

local Sidebar = require("./sidebar")

local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local CONFIG = tern.plugin.data .. "/jira.json"
local HOME = tern.getenv("HOME") or ""
local DEFAULT_REPOS = {
	Backend = { path = "~/projects/backend", base = "origin/develop", labels = { "Backend" }, summaryPrefixes = { "[BE]" } },
}
local DEFAULT_REPO = "Backend"
local DEFAULT_BASE = "origin/develop"
local KEY_PATTERN = "^%u[%u%d]+%-%d+$"
local KEY_IN_TEXT = "%f[%w](%u[%u%d]+%-%d+)%f[^%w]"
local BLOCK = "jira-sprint.sprint"
local OMP_SESSIONS = HOME .. "/.local/bin/omp-sessions"
-- Shared with sessions.luau.
local AGENTS_KEY = "open-agents"
local PUBLISH_MS = 1500

-- The chord prefix follows Tern's `keymap_prefix` setting (settings.json beside plugin-data/).
local function keymap_prefix(): string
	local config = string.match(tern.plugin.data, "^(.*)/plugin%-data/[^/]+/?$")
	local ok, prefix = pcall(function()
		return tern.json.decode(tern.fs.read(config .. "/settings.json", 1048576)).keymap_prefix
	end)
	return if ok and type(prefix) == "string" and prefix ~= "" then prefix else "ctrl+b"
end
local PREFIX = keymap_prefix()

tern.command({
	id = "open",
	title = "Work sidebar",
	icon = "list",
	keys = { PREFIX .. ">i" },
	run = Sidebar.toggle,
})

tern.command({
	id = "ideas",
	title = "Work sidebar: Ideas",
	icon = "list",
	keys = { PREFIX .. ">shift+i" },
	run = Sidebar.toggleIdeas,
})

-- Implement ----------------------------------------------------------------------------------------

type Repo = { path: string, base: string }
type Run = { status: number, stdout: string, stderr: string, timed_out: boolean }

local function expand(path: string): string
	return (string.gsub(path, "^~", HOME))
end

local function url_decode(s: string): string
	s = string.gsub(s, "+", " ")
	return (string.gsub(s, "%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) :: number)
	end))
end

local function parse_query(query: string): { [string]: string }
	local out = {}
	for pair in string.gmatch(query, "[^&]+") do
		local k, v = string.match(pair, "^([^=]+)=(.*)$")
		if k then
			out[url_decode(k)] = url_decode(v :: string)
		end
	end
	return out
end

local function first_line(s: string): string
	return string.match(s, "[^\r\n]+") or s
end

-- First six words of the summary in camelCase, as the existing branches are (`upgradeMongo8`).
local function camel_slug(summary: string): string
	local parts = {}
	for word in string.gmatch(summary, "%w+") do
		local lower = string.lower(word)
		table.insert(parts, if #parts == 0 then lower else string.upper(string.sub(lower, 1, 1)) .. string.sub(lower, 2))
		if #parts == 6 then
			break
		end
	end
	local slug = string.sub(table.concat(parts), 1, 40)
	return if slug == "" then "work" else slug
end

local function load_config(): ({ [string]: any }, string?)
	local ok, cfg = pcall(function()
		return tern.json.decode(tern.fs.read(CONFIG, 1048576))
	end)
	if ok and type(cfg) == "table" and type(cfg.repos) == "table" then
		return cfg.repos, if type(cfg.defaultRepo) == "string" then cfg.defaultRepo else nil
	end
	return DEFAULT_REPOS, DEFAULT_REPO
end

local function to_repo(entry: any): Repo?
	if type(entry) == "table" and type(entry.path) == "string" then
		return { path = expand(entry.path), base = entry.base or DEFAULT_BASE }
	end
	return nil
end

local function list_has(list: any, wanted: string): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, v in list do
		if type(v) == "string" and string.lower(v) == string.lower(wanted) then
			return true
		end
	end
	return false
end

-- The repository for an issue: the link's `repo`, then label rules, then summary prefixes, then defaultRepo.
-- The third return value says which rule matched, for the toast.
local function resolve_repo(q: { [string]: string }): (Repo?, string?, string?)
	local repos, default = load_config()
	if q.repo and q.repo ~= "" then
		local path = expand(q.repo)
		for _, entry in repos do
			local repo = to_repo(entry)
			if repo and repo.path == path then
				return repo, nil, "link"
			end
		end
		return { path = path, base = DEFAULT_BASE }, nil, "link"
	end
	local labels = q.labels or ""
	for label in string.gmatch(labels, "[^,]+") do
		for name, entry in repos do
			local repo = to_repo(entry)
			if repo and (string.lower(name) == string.lower(label) or list_has(entry.labels, label)) then
				return repo, nil, "label " .. label
			end
		end
	end
	local summary = q.summary or ""
	for _, entry in repos do
		local repo = to_repo(entry)
		if repo and type(entry.summaryPrefixes) == "table" then
			for _, prefix in entry.summaryPrefixes do
				if type(prefix) == "string" and prefix ~= "" and string.sub(summary, 1, #prefix) == prefix then
					return repo, nil, "summary " .. prefix
				end
			end
		end
	end
	local fallback = if default then to_repo(repos[default]) else nil
	if fallback then
		return fallback, nil, "defaultRepo " .. (default :: string)
	end
	local shown = if labels == "" then "no labels" else "labels " .. labels
	return nil, "No repository for " .. shown .. ". Add a rule under \"repos\" or a \"defaultRepo\" in " .. CONFIG, nil
end

local function run(argv: { string }, cb: (Run, any) -> ())
	local ok, err = pcall(tern.process.run, argv, { env = { PATH = PATH, HOME = HOME }, timeout_ms = 120000 }, cb)
	if not ok then
		cb({ status = -1, stdout = "", stderr = tostring(err), timed_out = false }, nil)
	end
end

local function git(args: { string }, cb: (Run, any) -> ())
	local argv = { "git" }
	for _, a in args do
		table.insert(argv, a)
	end
	run(argv, cb)
end

-- Sessions ----------------------------------------------------------------------------------------

local function line_of(p: any): string?
	local running = p.running
	return if type(running) == "table" and type(running.line) == "string" then running.line else nil
end

local function is_omp(p: any): boolean
	for _, v in { p.program, line_of(p) } do
		if type(v) == "string" and string.match(v, "%f[%w]omp%f[^%w]") then
			return true
		end
	end
	return false
end

-- Agent states from `agent_state` events: `cx.agents:list()` costs too much for a timer that polls (it
-- reads every agent's last message), so the panes come from `cx.session:panes()` and their state from here.
local agentStates: { [number]: string } = {}
tern.on("agent_state", function(ev, _cx)
	agentStates[ev.pane] = if ev.new == "exited" then nil else ev.new
end)

-- Session ids of the panes `resume` opened (pane id as a string -> session id): a tab launched with a
-- command shows no `running` line to read the id from. Kept in tern.kv across plugin reloads.
local RESUMED_KEY = "resumed-panes"
local resumed: { [string]: string } = (function()
	local ok, v = pcall(tern.kv.get, RESUMED_KEY)
	return if ok and type(v) == "table" then v else {}
end)()

type OpenAgent = {
	pane: number,
	title: string,
	cwd: string,
	state: string,
	-- The session id on its command line: `omp --resume <id>` or `omp --restore '<…>_<id>.jsonl'`.
	sid: string?,
	-- Its Tern session and tab; nil while parked.
	session: number?,
	tab: number?,
	parked: boolean,
}

-- The live omp panes, in every Tern session.
local function omp_agents(cx: any): { OpenAgent }
	local sessionOf: { [number]: number } = {}
	for _, info in cx.session:sessions() do
		for _, tab in (if type(info.tabs) == "table" then info.tabs else {}) do
			sessionOf[tab] = info.id
		end
	end
	local out: { OpenAgent } = {}
	for _, p in cx.session:panes() do
		if p.kind == "agent" and p.exited == nil and is_omp(p) then
			local line = line_of(p) or ""
			local tab = if type(p.tab) == "number" then p.tab else nil
			table.insert(out, {
				pane = p.pane,
				title = if type(p.title) == "string" then p.title else "",
				cwd = if type(p.cwd) == "string" then p.cwd else "",
				state = agentStates[p.pane] or (if p.busy then "working" else "idle"),
				sid = string.match(line, "%-%-resume%s+['\"]?([%x%-]+)")
					or string.match(line, "_(%x+%-%x+%-%x+%-%x+%-%x+)%.jsonl")
					or resumed[string.format("%d", p.pane)],
				session = tab and sessionOf[tab],
				tab = tab,
				parked = p.parked == true,
			})
		end
	end
	return out
end

local published: string? = nil

-- Publishes the open omp panes for the Sessions tab while a Work block exists; writes only changes.
local function publish(cx: any)
	local present = false
	-- Every pane, to forget resumed panes that closed.
	local live: { [string]: boolean } = {}
	for _, p in cx.session:panes() do
		present = present or p.block == BLOCK
		live[string.format("%d", p.pane)] = true
	end
	if not present then
		return
	end
	local agents = omp_agents(cx)
	local pruned = false
	for pane in resumed do
		if not live[pane] then
			resumed[pane] = nil
			pruned = true
		end
	end
	if pruned then
		tern.kv.set(RESUMED_KEY, resumed)
	end
	local encoded = tern.json.encode(agents)
	if encoded == published then
		return
	end
	published = encoded
	tern.kv.set(AGENTS_KEY, { stamp = tern.now(), agents = agents })
end

local function publish_loop()
	tern.timer(PUBLISH_MS, function(cx)
		if cx then
			local ok, err = pcall(publish, cx)
			if not ok then
				tern.log.warn("Work sidebar: publishing open agents: " .. tostring(err))
			end
		end
		publish_loop()
	end)
end
publish_loop()

-- Focuses `pane`, switching to its Tern session and unparking it as needed; false when it isn't open.
local function jump(cx: any, pane: number): boolean
	local agent = nil
	for _, a in omp_agents(cx) do
		if a.pane == pane then
			agent = a
		end
	end
	if not agent then
		return false
	end
	local function reveal(rcx: any)
		local info = rcx.session:pane(pane)
		if info and info.parked then
			rcx.layout:unpark(pane)
		end
		rcx.layout:focus(pane)
	end
	local current = cx.sessions:current()
	if agent.session and current and current.id ~= agent.session then
		cx.sessions:switch(agent.session)
		-- The switch settles after this call; reveal the pane in the shown session then.
		tern.timer(50, function(later)
			local ok, err = pcall(reveal, later or cx)
			if not ok then
				tern.log.warn("Work sidebar: jump to pane " .. tostring(pane) .. ": " .. tostring(err))
			end
		end)
	else
		reveal(cx)
	end
	return true
end

local function agent_title(a: OpenAgent): string
	return if a.title ~= "" then a.title else "omp"
end

-- Resumes session `id` in a new tab in `cwd` (HOME when it's gone), or jumps to the pane already running it.
local function resume(cx: any, id: string, cwd: string?, heading: string)
	if not string.match(id, "^%x[%x%-]*$") then
		cx:toast("error", "Not an omp session id", id)
		return
	end
	for _, a in omp_agents(cx) do
		if a.sid == id and jump(cx, a.pane) then
			cx:toast("info", heading .. ": already open, jumped to it", agent_title(a))
			return
		end
	end
	local dir = if cwd and cwd ~= "" and tern.fs.exists(cwd) then cwd else HOME
	local pane = cx.layout:new_tab({ cwd = dir, command = "omp --resume " .. id })
	if not pane then
		cx:toast("error", heading .. ": couldn't open a tab", "omp --resume " .. id)
		return
	end
	resumed[string.format("%d", pane)] = id
	tern.kv.set(RESUMED_KEY, resumed)
	local gone = if cwd and cwd ~= "" and dir ~= cwd then " (" .. cwd .. " is gone)" else ""
	cx:toast("success", heading, "omp --resume " .. id .. " in " .. dir .. gone)
end

local function has_key(text: string, key: string): boolean
	for k in string.gmatch(text, KEY_IN_TEXT) do
		if k == key then
			return true
		end
	end
	return false
end

-- An open omp pane working on `key`: its title holds the key, or it runs in the key's worktree.
local function open_agent_for(cx: any, key: string, worktree: string?): OpenAgent?
	for _, a in omp_agents(cx) do
		local cwd = string.gsub(a.cwd, "/+$", "")
		if has_key(agent_title(a), key) or (worktree and cwd == worktree) then
			return a
		end
	end
	return nil
end

-- `work://session/jump/<pane>` and `work://session/resume/<id>?cwd=…`; false for other links.
local function session_link(url: string, cx: any): boolean
	local kind, arg, query = string.match(url, "^work://session/(%a+)/([^?#]+)%??([^#]*)")
	if not kind then
		return false
	end
	if kind == "jump" then
		local pane = tonumber(arg)
		if not pane or not jump(cx, pane) then
			cx:toast("error", "That omp pane is gone", "Refresh the Sessions tab")
		end
	elseif kind == "resume" then
		local q = parse_query(query or "")
		resume(cx, url_decode(arg :: string), q.cwd, "Resumed omp session")
	else
		cx:toast("error", "Unknown session link", url)
	end
	return true
end

-- Worktrees of `repo` as { path, branch } from `git worktree list --porcelain`.
local function parse_worktrees(out: string): { { path: string, branch: string? } }
	local list = {}
	local current = nil
	for line in string.gmatch(out, "[^\n]+") do
		local path = string.match(line, "^worktree (.+)$")
		if path then
			current = { path = path, branch = nil }
			table.insert(list, current)
		elseif current then
			local branch = string.match(line, "^branch refs/heads/(.+)$")
			if branch then
				current.branch = branch
			end
		end
	end
	return list
end

local function start_omp(cx: any, key: string, cwd: string, note: string)
	local ok, err = pcall(function()
		cx.agents:start({ prompt = "/implement " .. key, cwd = cwd, how = "tab" })
	end)
	if ok then
		cx:toast("success", key .. ": no session yet, started omp", note .. " " .. cwd)
	else
		cx:toast("error", key .. ": couldn't start omp", tostring(err))
	end
end

local function implement_fresh(cx: any, key: string, q: { [string]: string }, repo: Repo)
	local root = repo.path
	if not tern.fs.exists(root .. "/.git") then
		cx:toast("error", "Implement " .. key, root .. " is not a git checkout")
		return
	end
	local parent, name = string.match(root, "^(.*)/([^/]+)$")
	local worktree = string.format("%s/%s-worktrees/%s", parent :: string, name :: string, key)
	local fail = function(rcx: any, what: string, r: Run)
		(rcx or cx):toast("error", key .. ": " .. what, first_line(r.stderr ~= "" and r.stderr or r.stdout))
	end

	git({ "-C", root, "worktree", "list", "--porcelain" }, function(r, rcx)
		if r.status ~= 0 then
			return fail(rcx, "git worktree list failed", r)
		end
		for _, wt in parse_worktrees(r.stdout) do
			local branch = wt.branch or ""
			local base = string.match(wt.path, "[^/]+$")
			if base == key or string.sub(branch, 1, #("feature/" .. key .. "_")) == "feature/" .. key .. "_" then
				return start_omp(rcx or cx, key, wt.path, "reused worktree")
			end
		end
		if tern.fs.exists(worktree) then
			return (rcx or cx):toast("error", key .. ": " .. worktree .. " exists but is not a worktree of " .. name)
		end
		git({ "-C", root, "for-each-ref", "--format=%(refname:short)", "refs/heads/feature/" .. key .. "_*" }, function(b, bcx)
			local existing = string.match(b.stdout, "[^\n]+")
			if existing then
				git({ "-C", root, "worktree", "add", worktree, existing }, function(a, acx)
					if a.status ~= 0 then
						return fail(acx, "git worktree add failed", a)
					end
					start_omp(acx or cx, key, worktree, "new worktree on existing " .. existing)
				end)
				return
			end
			local branch = "feature/" .. key .. "_" .. camel_slug(q.summary or "")
			local remote, remote_branch = string.match(repo.base, "^([^/]+)/(.+)$")
			local fetch = if remote then { "-C", root, "fetch", "--quiet", remote :: string, remote_branch :: string } else { "-C", root, "fetch", "--quiet" }
			;(bcx or cx):toast("info", key .. ": creating worktree", branch .. " from " .. repo.base)
			git(fetch, function(f, fcx)
				if f.status ~= 0 then
					return fail(fcx, "git fetch failed", f)
				end
				git({ "-C", root, "worktree", "add", "--no-track", "-b", branch, worktree, repo.base }, function(a, acx)
					if a.status ~= 0 then
						return fail(acx, "git worktree add failed", a)
					end
					start_omp(acx or cx, key, worktree, "new worktree " .. branch)
				end)
			end)
		end)
	end)
end

-- Reuses a session for `key` when there is one (an open pane, else a resumable session with the key among its
-- keys), else starts a fresh one in the key's worktree.
local function implement(cx: any, key: string, q: { [string]: string })
	local repo, err, rule = resolve_repo(q)
	local worktree = nil
	if repo then
		local parent, name = string.match(repo.path, "^(.*)/([^/]+)$")
		if parent and name then
			worktree = string.format("%s/%s-worktrees/%s", parent, name, key)
		end
	end
	local open = open_agent_for(cx, key, worktree)
	if open and jump(cx, open.pane) then
		cx:toast("info", key .. ": jumped to its open omp session", agent_title(open))
		return
	end
	run({ OMP_SESSIONS, "find", key, "--json" }, function(r, rcx)
		local c = rcx or cx
		local best = nil
		-- `find` exits 1 when nothing matches.
		if r.status == 0 then
			local ok, v = pcall(tern.json.decode, r.stdout)
			best = if ok and type(v) == "table" and type(v[1]) == "table" then v[1] else nil
		elseif r.status ~= 1 then
			tern.log.warn("Work sidebar: omp-sessions find " .. key .. ": " .. first_line(r.stderr))
		end
		if best and type(best.id) == "string" and type(best.keys) == "table" and table.find(best.keys, key) then
			resume(c, best.id, if type(best.cwd) == "string" then best.cwd else nil, key .. ": resumed its omp session")
			return
		end
		if not repo then
			c:toast("error", "Implement " .. key, err)
			return
		end
		c:toast("info", key .. ": " .. string.match(repo.path, "[^/]+$") :: string, "repository chosen by " .. (rule or "?"))
		implement_fresh(c, key, q, repo)
	end)
end

tern.route.link(function(link, cx)
	if Sidebar.link(link.url, cx) or session_link(link.url, cx) then
		return { handled = true }
	end
	local key, query = string.match(link.url, "^jira%-sprint://implement/([^?]+)%??(.*)$")
	if not key then
		return nil
	end
	key = string.upper(url_decode(key))
	if not string.match(key, KEY_PATTERN) then
		cx:toast("error", "Implement: not a Jira key", key)
		return { handled = true }
	end
	implement(cx, key, parse_query(query or ""))
	return { handled = true }
end)
