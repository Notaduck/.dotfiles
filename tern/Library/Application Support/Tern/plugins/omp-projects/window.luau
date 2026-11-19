-- Claude Projects: Claude-Desktop-style projects on top of Tern sessions.
--
-- A project is a Tern session named after it; the vertical tab list shows each session as a
-- category and each tab in it as a chat. New Session asks for a project and opens a Claude Code
-- chat in its folder (creating the session the first time); New Tab inside a project session opens
-- another Claude Code chat in the same folder. The agent is Tern's `agent_command` setting (default
-- `claude`). Projects come from projects.json in the plugin's data folder:
-- explicit `projects` entries ({name, dir, review?, gh_user?}) first, then every folder under
-- `roots`. In a `review` project a new chat also asks which open PR to review (see pick_pr).

local HOME = tern.getenv("HOME") or ""
local CONFIG = tern.plugin.data .. "/projects.json"
local DEFAULT_CONFIG = [[
{
  "roots": ["~/projects"],
  "projects": []
}
]]
-- kv "sessions": session name -> project folder, for every session this plugin opened.
local KV_SESSIONS = "sessions"

type Project = { name: string, dir: string, configured: boolean }

local function expand(p: string): string
	if p == "~" then
		return HOME
	end
	if string.sub(p, 1, 2) == "~/" then
		return HOME .. string.sub(p, 2)
	end
	return p
end

local function pretty(p: string): string
	if HOME ~= "" and (p == HOME or string.sub(p, 1, #HOME + 1) == HOME .. "/") then
		return "~" .. string.sub(p, #HOME + 1)
	end
	return p
end

local function basename(p: string): string
	return string.match(p, "([^/]+)/*$") or p
end

local function is_dir(p: string): boolean
	return (pcall(tern.fs.list, p))
end

local function load_config(): ({ [string]: any }, string?)
	if not tern.fs.exists(CONFIG) then
		tern.fs.mkdir(tern.plugin.data)
		tern.fs.write(CONFIG, DEFAULT_CONFIG)
	end
	local ok, cfg = pcall(function()
		return tern.json.decode(tern.fs.read(CONFIG))
	end)
	if not ok or type(cfg) ~= "table" then
		return { roots = {}, projects = {} }, tostring(cfg)
	end
	return cfg, nil
end

local function save_config(cfg: { [string]: any })
	cfg.roots = tern.json.array(cfg.roots or {})
	cfg.projects = tern.json.array(cfg.projects or {})
	tern.fs.write(CONFIG, tern.json.encode(cfg, true) .. "\n")
end

-- Configured projects in file order, then the folders under each root not configured already.
local function list_projects(cfg: { [string]: any }): { Project }
	local out: { Project } = {}
	local names, dirs = {}, {}
	for _, p in cfg.projects or {} do
		if type(p) == "table" and type(p.name) == "string" and type(p.dir) == "string" and not names[p.name] then
			local dir = expand(p.dir)
			table.insert(out, { name = p.name, dir = dir, configured = true })
			names[p.name] = true
			dirs[dir] = true
		end
	end
	for _, root in cfg.roots or {} do
		if type(root) == "string" then
			local r = expand(root)
			local ok, entries = pcall(tern.fs.list, r)
			if ok then
				for _, n in entries do
					local dir = r .. "/" .. n
					if string.sub(n, 1, 1) ~= "." and not names[n] and not dirs[dir] and is_dir(dir) then
						table.insert(out, { name = n, dir = dir, configured = false })
						names[n] = true
						dirs[dir] = true
					end
				end
			end
		end
	end
	return out
end

local function remember(name: string, dir: string)
	local map = tern.kv.get(KV_SESSIONS) or {}
	if map[name] ~= dir then
		map[name] = dir
		tern.kv.set(KV_SESSIONS, map)
	end
end

-- The folder of the project session `name`, nil for sessions that aren't projects.
local function project_dir(name: string): string?
	local map = tern.kv.get(KV_SESSIONS)
	if map and type(map[name]) == "string" then
		return map[name]
	end
	local cfg = load_config()
	for _, p in cfg.projects or {} do
		if type(p) == "table" and p.name == name and type(p.dir) == "string" then
			return expand(p.dir)
		end
	end
	return nil
end

local function agent_command(cx): string
	local cmd = cx.settings:get("agent_command")
	if type(cmd) == "string" and cmd ~= "" then
		return cmd
	end
	return "claude"
end

local function shell_quote(s: string): string
	return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function find_session(cx, name: string)
	local host = cx.hosts:current().id
	for _, s in cx.sessions:list() do
		if s.host == host and s.name == name then
			return s
		end
	end
	return nil
end

local function open_chat(cx, name: string, dir: string)
	if not is_dir(dir) then
		cx:toast("error", "No folder " .. pretty(dir), "Fix the project in projects.json (Edit Projects)")
		return
	end
	remember(name, dir)
	-- The new tab (or a new session's first tab) starts Claude Code through tab_created below.
	local s = find_session(cx, name)
	if s then
		cx.sessions:switch(s.id)
		cx.layout:new_tab({ cwd = dir })
	else
		cx.sessions:create({ name = name, cwd = dir })
	end
end

local function pick_project(cx)
	local cfg, err = load_config()
	if err then
		cx:toast("error", "projects.json doesn't parse", err)
	end
	local current = cx.sessions:current().name
	local items = {}
	for _, p in list_projects(cfg) do
		local open = find_session(cx, p.name) ~= nil
		table.insert(items, {
			label = p.name,
			detail = pretty(p.dir) .. (if open then " · open" else ""),
			group = if p.configured then "Projects" else "Folders",
			icon = "folder",
			current = p.name == current,
			project = p.name,
			dir = p.dir,
		})
	end
	table.insert(items, { label = "Shell session", detail = "no project", group = "Other", icon = "terminal", plain = true })
	table.insert(items, { label = "Edit projects…", detail = pretty(CONFIG), group = "Other", icon = "doc", edit = true })
	cx:pick({ items = items, placeholder = "New Claude chat in project…", icon = "folder", action = "start claude" })
		:next(function(item, perr, cx2)
			if perr then
				tern.log.warn("omp-projects pick:", perr)
			end
			if not item or not cx2 then
				return
			end
			if item.plain then
				cx2:command("new_session")
			elseif item.edit then
				cx2:open(CONFIG, "tab")
			else
				open_chat(cx2, item.project, item.dir)
			end
		end)
end

-- Adds the focused pane's folder as a named project (a second category over one repository, a
-- worktree folder, …) and opens a chat in it.
local function add_project(cx)
	local pane = cx.session:focused()
	local info = pane and cx.session:pane(pane)
	local dir = info and info.cwd or ""
	if dir == "" then
		cx:toast("error", "The focused pane has no folder")
		return
	end
	cx:prompt({ value = basename(dir), placeholder = "Project name for " .. pretty(dir), icon = "folder", action = "add" })
		:next(function(name, _, cx2)
			if not name or not cx2 then
				return
			end
			name = string.match(name, "^%s*(.-)%s*$") or ""
			if name == "" then
				return
			end
			local cfg, err = load_config()
			if err then
				cx2:toast("error", "projects.json doesn't parse", err)
				return
			end
			local projects = cfg.projects or {}
			for _, p in projects do
				if type(p) == "table" and p.name == name then
					cx2:toast("error", "A project named " .. name .. " exists", "Edit Projects to change it")
					return
				end
			end
			table.insert(projects, { name = name, dir = pretty(dir) })
			cfg.projects = projects
			save_config(cfg)
			open_chat(cx2, name, dir)
		end)
end

tern.command({
	id = "new_chat",
	title = "New Claude Chat in Project…",
	icon = "folder",
	keys = { "ctrl+b>s" },
	run = pick_project,
})
tern.command({ id = "add_project", title = "Add This Folder as a Project…", icon = "folder", run = add_project })
tern.command({
	id = "edit_projects",
	title = "Edit Projects",
	icon = "doc",
	run = function(cx)
		load_config()
		cx:open(CONFIG, "tab")
	end,
})

-- New Session (its key, the palette and the sidebar's button) picks a project instead.
tern.override("new_session", function(cx)
	pick_project(cx)
	return true
end)

-- Every new tab in a project session — New Tab, the session's + in the sidebar, the first tab of
-- a new project session — starts Claude Code in its shell, so quitting it leaves a shell in the project.
-- Only a freshly made shell counts: a pane moved into a new tab, or a tab that runs a command
-- or opens a file, is left alone.
local FRESH_MS = 3000
local fresh: { [number]: number } = {}

tern.on("pane_created", function(ev, _)
	local now = tern.now()
	for pane, born in fresh do
		if now - born > FRESH_MS then
			fresh[pane] = nil
		end
	end
	fresh[ev.pane] = now
end)

local function session_of_tab(cx, tab: number): string?
	for _, s in cx.session:sessions() do
		for _, t in s.tabs do
			if t == tab then
				return s.name
			end
		end
	end
	return nil
end

-- Review projects (`"review": true`): a new chat first lists the repository's open pull requests
-- (gh, no model involved) and starts Claude Code with `/pr-review <number>` as its first prompt,
-- naming the tab after the PR. Cancelling the pick starts a plain chat. `gh_user` picks the gh
-- account whose token lists them.
local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local DECISIONS = { APPROVED = "approved", CHANGES_REQUESTED = "changes requested", REVIEW_REQUIRED = "review required" }

local function configured_project(name: string): { [string]: any }?
	local cfg = load_config()
	for _, p in cfg.projects or {} do
		if type(p) == "table" and p.name == name then
			return p
		end
	end
	return nil
end

local function pr_items(prs: { any }, gh_user: string?): { any }
	local items = {}
	-- Others' PRs first, then yours (the skill self-reviews those).
	for _, want_mine in { false, true } do
		for _, pr in prs do
			local author = pr.author and pr.author.login or "?"
			local mine = author == gh_user
			if mine == want_mine then
				local detail = { author }
				if pr.isDraft then
					table.insert(detail, "draft")
				end
				local decision = DECISIONS[pr.reviewDecision or ""]
				if decision then
					table.insert(detail, decision)
				end
				table.insert(detail, pr.headRefName)
				table.insert(items, {
					label = "#" .. pr.number .. " " .. pr.title,
					detail = table.concat(detail, " · "),
					group = if mine then "Yours (self-review)" else "To review",
					icon = "pr",
					number = pr.number,
					title = pr.title,
				})
			end
		end
	end
	return items
end

-- Calls `done` with the review prompt for the chosen PR, or nil when there is nothing to pick.
local function pick_pr(tab: number, dir: string, gh_user: string?, done: (string?) -> ())
	local function list(token: string?)
		local env = { PATH = PATH }
		if token then
			env.GH_TOKEN = token
		end
		local argv = { "gh", "pr", "list", "--state", "open", "--limit", "100", "--json", "number,title,author,isDraft,reviewDecision,headRefName" }
		tern.process.run(argv, { cwd = dir, env = env, timeout_ms = 20000 }, function(res, cx)
			if not cx then
				return
			end
			if res.status ~= 0 then
				cx:toast("error", "gh pr list failed in " .. pretty(dir), res.stderr)
				done(nil)
				return
			end
			local prs = tern.json.decode(res.stdout)
			if #prs == 0 then
				cx:toast("info", "No open pull requests in " .. pretty(dir))
				done(nil)
				return
			end
			cx:pick({ items = pr_items(prs, gh_user), placeholder = "Pull request to review…", icon = "pr", action = "review" })
				:next(function(item, _, cx2)
					if not item or not cx2 then
						done(nil)
						return
					end
					cx2.layout:name_tab(tab, item.title)
					done("/pr-review " .. item.number)
				end)
		end)
	end
	if not gh_user then
		list(nil)
		return
	end
	tern.process.run({ "gh", "auth", "token", "--user", gh_user }, { env = { PATH = PATH }, timeout_ms = 10000 }, function(res, cx)
		if res.status ~= 0 then
			if cx then
				cx:toast("error", "gh auth token --user " .. gh_user .. " failed", res.stderr)
			end
			done(nil)
			return
		end
		list((string.gsub(res.stdout, "%s+$", "")))
	end)
end

-- Typing into a shell that hasn't drawn its prompt yet gets scrambled by zle; wait for the prompt
-- (OSC 133, `at_prompt`), then a beat for zle to take input.
local READY_TRIES = 80 -- × 100 ms
local function run_when_ready(pane: number, text: string, tries: number)
	tern.timer(100, function(cx)
		if not cx then
			return
		end
		local info = cx.session:pane(pane)
		if not info then
			return
		end
		if info.at_prompt or tries <= 1 then
			tern.timer(150, function(cx2)
				if cx2 and cx2.session:pane(pane) then
					cx2:run(pane, text)
				end
			end)
			return
		end
		run_when_ready(pane, text, tries - 1)
	end)
end

-- The tab's freshly made pane. Another plugin may already have split the new tab (jira-sprint's Work
-- sidebar pins itself to the right of every shown tab), so the root isn't always a single pane.
local function fresh_pane(node): number?
	if not node then
		return nil
	end
	if node.pane then
		return if fresh[node.pane] then node.pane else nil
	end
	return fresh_pane(node[1]) or fresh_pane(node[2])
end

local function start_agent(cx, tab: number)
	local layout = cx.session:layout(tab)
	local pane = layout and fresh_pane(layout.root)
	if not pane then
		return
	end
	local born = fresh[pane]
	fresh[pane] = nil
	if not born or tern.now() - born > FRESH_MS then
		return
	end
	local name = session_of_tab(cx, tab)
	local dir = name and project_dir(name)
	if not name or not dir then
		return
	end
	local info = cx.session:pane(pane)
	if not info or info.kind ~= "terminal" or info.running then
		return
	end
	-- A tab opened from the sidebar's + starts in the focused pane's folder, which may belong to
	-- another session; move the shell into the project first. A first prompt goes on the command
	-- line, so it reaches Claude Code however long it takes to come up.
	-- Everything `launch` needs from `cx` is read now: in a review project it runs after the PR
	-- pick, by which time this `cx` is gone ("userdata has been destructed").
	local cwd = info.cwd
	local agent = agent_command(cx)
	local function launch(prompt: string?)
		local cmd = agent
		if prompt then
			cmd = cmd .. " " .. shell_quote(prompt)
		end
		if cwd ~= dir then
			cmd = "cd -- " .. shell_quote(dir) .. " && " .. cmd
		end
		run_when_ready(pane, cmd .. "\r", READY_TRIES)
	end
	local project = configured_project(name)
	if project and project.review == true then
		pick_pr(tab, dir, if type(project.gh_user) == "string" then project.gh_user else nil, launch)
	else
		launch(nil)
	end
end

tern.on("tab_created", function(ev, _)
	-- pane_created may come after tab_created.
	tern.timer(50, function(cx)
		if cx then
			start_agent(cx, ev.tab)
		end
	end)
end)
