-- GitHub Actions: workflow runs of the repository the focused terminal is in (kv "cwd", set by window.luau).

local PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
local TICK_MS = 1000
local PANE_CHECK_TICKS = 5
local RUNS_FETCHED = 50
local FINISHED_SHOWN = 10
local INTERVALS = { 0, 1, 2, 5, 10, 15 }
local DEFAULT_INTERVAL = 1

local ui = tern.ui

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

-- ISO 8601 UTC timestamps as GitHub returns them ("2026-11-05T13:43:03Z").
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
		return "—"
	end
	local d = os.time() - t
	if d < 60 then
		return "just now"
	elseif d < 3600 then
		return string.format("%dm ago", d // 60)
	elseif d < 86400 then
		return string.format("%dh ago", d // 3600)
	end
	return string.format("%dd ago", d // 86400)
end

local function duration(a: number?, b: number?): string
	if not a or not b or b < a then
		return "—"
	end
	local d = b - a
	if d < 60 then
		return string.format("%ds", d)
	elseif d < 3600 then
		return string.format("%dm %02ds", d // 60, d % 60)
	end
	return string.format("%dh %02dm", d // 3600, d % 3600 // 60)
end

-- Processes ---------------------------------------------------------------------------------------

type Run = { status: number, stdout: string, stderr: string, timed_out: boolean }

local function run(argv: { string }, timeout_ms: number, cb: (Run) -> ())
	local ok, err = pcall(tern.process.run, argv, { env = { PATH = PATH }, timeout_ms = timeout_ms }, cb)
	if not ok then
		cb({ status = -1, stdout = "", stderr = tostring(err), timed_out = false })
	end
end

local function first_line(s: string): string
	local line = string.match(s, "[^\r\n]+") or s
	return (string.gsub(line, "^%s+", ""))
end

local function gh(path: string, jq: string, cb: (any?, string?) -> ())
	run({ "gh", "api", path, "--jq", jq }, 30000, function(r)
		if r.status ~= 0 then
			cb(nil, if r.timed_out then "gh timed out" else first_line(r.stderr))
			return
		end
		local ok, value = pcall(tern.json.decode, r.stdout)
		if not ok then
			cb(nil, "gh returned invalid JSON")
			return
		end
		cb(value, nil)
	end)
end

-- State -------------------------------------------------------------------------------------------

type Job = {
	name: string,
	status: string,
	conclusion: string?,
	started_at: string?,
	completed_at: string?,
	html_url: string,
	steps_done: number,
	steps_total: number,
	step: string?,
}
type GhRun = {
	id: number,
	run_attempt: number,
	name: string?,
	display_title: string,
	head_branch: string?,
	event: string,
	status: string,
	conclusion: string?,
	run_started_at: string?,
	updated_at: string?,
	html_url: string,
	actor: string?,
}
type Repo = { root: string, slug: string, branch: string? }

type State = {
	cx: any,
	alive: boolean,
	cwd: string?,
	repo: Repo?,
	repo_error: string?,
	runs: { GhRun }?,
	runs_error: string?,
	jobs: { [string]: { Job } },
	interval: number,
	gen: number,
	resolve_gen: number,
	inflight: number?,
	next_fetch: number?,
	updated: number?,
	ticks: number,
}

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

local function job_key(r: GhRun): string
	return tostring(r.id) .. "/" .. tostring(r.run_attempt)
end

local function active_runs(s: State): { GhRun }
	local out: { GhRun } = {}
	for _, r in s.runs or {} do
		if r.status ~= "completed" then
			table.insert(out, r)
		end
	end
	return out
end

local function finished_runs(s: State): { GhRun }
	local out: { GhRun } = {}
	for _, r in s.runs or {} do
		if r.status == "completed" then
			table.insert(out, r)
			if #out >= FINISHED_SHOWN then
				break
			end
		end
	end
	return out
end

local function tone_of(status: string, conclusion: string?): string
	if status == "in_progress" then
		return "warning"
	elseif status ~= "completed" then
		return "info"
	elseif conclusion == "success" then
		return "success"
	elseif conclusion == "skipped" or conclusion == "cancelled" or conclusion == "neutral" then
		return "muted"
	end
	return "error"
end

local function label_of(status: string, conclusion: string?): string
	if status ~= "completed" then
		return if status == "in_progress" then "running" else status
	end
	return conclusion or "done"
end

local function schedule_next(s: State)
	s.next_fetch = if s.interval > 0 then os.time() + s.interval * 60 else nil
end

-- Fetching ----------------------------------------------------------------------------------------

local RUNS_JQ = "[.workflow_runs[] | {id, run_attempt, name, display_title, head_branch, event, status, conclusion, run_started_at, updated_at, html_url, actor: .actor.login}]"
local JOBS_JQ = "[.jobs[] | {name, status, conclusion, started_at, completed_at, html_url,"
	.. " steps_total: ((.steps // []) | length),"
	.. " steps_done: ([.steps[]? | select(.status == \"completed\")] | length),"
	.. " step: ([.steps[]? | select(.status == \"in_progress\") | .name] | first)}]"

local function fetch(s: State)
	local repo = s.repo
	if not repo or s.inflight == s.gen then
		return
	end
	local gen = s.gen
	s.inflight = gen
	schedule_next(s)
	render(s)
	gh(string.format("repos/%s/actions/runs?per_page=%d", repo.slug, RUNS_FETCHED), RUNS_JQ, function(v, err)
		if gen ~= s.gen then
			return
		end
		if err then
			s.runs_error = err
			s.inflight = nil
			s.updated = os.time()
			render(s)
			return
		end
		s.runs = v
		s.runs_error = nil
		local jobs: { [string]: { Job } } = {}
		local pending = 1
		local function settle()
			pending -= 1
			if pending == 0 and gen == s.gen then
				s.jobs = jobs
				s.inflight = nil
				s.updated = os.time()
				render(s)
			end
		end
		for _, r in active_runs(s) do
			local key = job_key(r)
			pending += 1
			local path = string.format("repos/%s/actions/runs/%d/attempts/%d/jobs?per_page=100", repo.slug, r.id, r.run_attempt)
			gh(path, JOBS_JQ, function(js, jerr)
				jobs[key] = if jerr then s.jobs[key] else js
				settle()
			end)
		end
		settle()
	end)
end

-- "owner/repo" of a GitHub remote URL: git@host:o/r.git, ssh://git@host/o/r, https://host/o/r.git.
local function parse_slug(url: string): string?
	local u = string.gsub(url, "/+$", "")
	u = string.gsub(u, "%.git$", "")
	local owner, name = string.match(u, "([^/:]+)/([^/:]+)$")
	if not owner then
		return nil
	end
	return owner .. "/" .. name
end

local function remote_url(remotes: string): string?
	local first: string? = nil
	for line in string.gmatch(remotes, "[^\n]+") do
		local name, url = string.match(line, "^(%S+)%s+(%S+)")
		if name and url then
			if name == "origin" then
				return url
			end
			first = first or url
		end
	end
	return first
end

local function no_repo(s: State, reason: string)
	s.gen += 1
	s.repo = nil
	s.runs = nil
	s.jobs = {}
	s.repo_error = reason
	render(s)
end

local function resolve(s: State, cwd: string)
	s.resolve_gen += 1
	local rg = s.resolve_gen
	run({ "git", "-C", cwd, "rev-parse", "--show-toplevel" }, 5000, function(top)
		if rg ~= s.resolve_gen then
			return
		end
		local root = if top.status == 0 then string.match(top.stdout, "[^\n]+") else nil
		if not root then
			no_repo(s, "Not inside a git repository")
			return
		end
		run({ "git", "-C", cwd, "remote", "-v" }, 5000, function(rem)
			if rg ~= s.resolve_gen then
				return
			end
			local url = if rem.status == 0 then remote_url(rem.stdout) else nil
			local slug = if url then parse_slug(url) else nil
			if not slug then
				no_repo(s, "This repository has no GitHub remote")
				return
			end
			run({ "git", "-C", cwd, "branch", "--show-current" }, 5000, function(br)
				if rg ~= s.resolve_gen then
					return
				end
				local branch = if br.status == 0 then string.match(br.stdout, "[^\n]+") else nil
				s.repo_error = nil
				local prev = s.repo
				if prev and prev.slug == slug and prev.root == root then
					prev.branch = branch
					render(s)
					return
				end
				s.gen += 1
				s.repo = { root = root :: string, slug = slug :: string, branch = branch }
				s.runs = nil
				s.runs_error = nil
				s.jobs = {}
				fetch(s)
			end)
		end)
	end)
end

local function followed_cwd(s: State): string?
	local ok, value = pcall(tern.kv.get, "cwd")
	local cwd = if ok and type(value) == "string" and value ~= "" then value else s.cx.cwd
	if not cwd then
		return nil
	end
	if string.sub(cwd, 1, 1) == "~" then
		return (tern.getenv("HOME") or "") .. string.sub(cwd, 2)
	end
	return cwd
end

local function tick(s: State)
	if not s.alive then
		return
	end
	s.ticks += 1
	if s.ticks % PANE_CHECK_TICKS == 0 and not pane_alive(s) then
		s.alive = false
		return
	end
	local ok, err = pcall(function()
		local cwd = followed_cwd(s)
		if cwd and cwd ~= s.cwd then
			s.cwd = cwd
			resolve(s, cwd)
		end
		if s.repo and s.next_fetch and os.time() >= s.next_fetch then
			fetch(s)
		elseif #active_runs(s) > 0 or s.next_fetch then
			render(s)
		end
	end)
	if not ok then
		tern.log.warn("gh-actions tick", err)
	end
	tern.timer(TICK_MS, function()
		tick(s)
	end)
end

local function requery(s: State)
	if s.repo then
		fetch(s)
	elseif s.cwd then
		resolve(s, s.cwd)
	end
end

-- View --------------------------------------------------------------------------------------------

local function keyed(node: any, key: string)
	node.p = node.p or {}
	node.p.key = key
	return node
end

local function interval_label(m: number): string
	return if m == 0 then "Off" else tostring(m) .. " min"
end

local function toolbar(s: State): any
	local status
	if s.inflight then
		status = ui.span("querying…", "muted")
	elseif s.updated then
		local next_in = if s.next_fetch then math.max(0, s.next_fetch - os.time()) else nil
		status = ui.span(
			"updated " .. ago(s.updated) .. (if next_in then string.format(" · next in %d:%02d", next_in // 60, next_in % 60) else ""),
			"muted"
		)
	else
		status = ui.span("", "muted")
	end
	local buttons = {
		ui.button("Refresh", { actions = { click = "refresh" }, size = "sm", icon = "refresh", keys = { "r" }, busy = s.inflight ~= nil }),
		ui.text(ui.span("Auto", "muted")),
	}
	for _, m in INTERVALS do
		table.insert(buttons, ui.button(interval_label(m), { actions = { click = "interval=" .. m }, size = "sm", on = m == s.interval }))
	end
	table.insert(buttons, ui.text(status))
	return ui.row(buttons)
end

local function repo_line(s: State): any
	local repo = s.repo
	if not repo then
		return ui.text({ ui.span("Folder ", "muted"), ui.span(s.cwd or "unknown", "path") })
	end
	local spans = {
		ui.link(repo.slug, "https://github.com/" .. repo.slug .. "/actions", "strong"),
		ui.span("  ", nil),
		ui.span(repo.root, "path muted"),
	}
	if repo.branch then
		table.insert(spans, ui.span("  on ", "muted"))
		table.insert(spans, ui.span(repo.branch, "mono"))
	end
	return ui.text(spans)
end

local function run_head(r: GhRun): any
	if not r.name or r.name == r.display_title then
		return { ui.link(r.display_title, r.html_url, "strong") }
	end
	return {
		ui.span(r.name, "strong"),
		ui.span(" · ", "muted"),
		ui.link(r.display_title, r.html_url),
	}
end

local function jobs_table(s: State, r: GhRun): any
	local jobs = s.jobs[job_key(r)]
	if not jobs then
		return ui.progress(nil, "Loading jobs…")
	end
	local rows = {}
	for _, j in jobs do
		if j.conclusion ~= "skipped" then
			local started = parse_time(j.started_at)
			local finished = parse_time(j.completed_at)
			local progress: any = ""
			if j.steps_total > 0 then
				progress = ui.meter_cell(j.steps_done / j.steps_total)
			end
			table.insert(rows, {
				id = j.html_url,
				menu = { "Open job" },
				cells = {
					{ text = { ui.link(j.name, j.html_url) }, dot = tone_of(j.status, j.conclusion) },
					label_of(j.status, j.conclusion),
					ui.span(j.step or "", "muted"),
					progress,
					duration(started, finished or (if j.status == "in_progress" then os.time() else nil)),
				},
			})
		end
	end
	return keyed(
		ui.table({
			{ id = "job", head = "Job", grow = 1, priority = 5 },
			{ id = "state", head = "State", priority = 4 },
			{ id = "step", head = "Current step", grow = 1, truncate = "end", priority = 1 },
			{ id = "progress", head = "Steps", priority = 2 },
			{ id = "took", head = "Took", align = "end", priority = 3 },
		}, rows, { selectable = true, empty = "No jobs yet" }),
		"jobs-" .. job_key(r)
	)
end

local function running_view(s: State): any
	local active = active_runs(s)
	local children = {}
	if #active == 0 then
		table.insert(children, ui.text(ui.span("Nothing running", "muted")))
	end
	for _, r in active do
		local started = parse_time(r.run_started_at)
		local meta = {
			ui.span(r.head_branch or "", "mono muted"),
			ui.span(string.format(" · %s · %s · %s", r.event, r.actor or "?", label_of(r.status, r.conclusion)), "muted"),
			ui.span(" · " .. duration(started, os.time()), "num muted"),
		}
		table.insert(children, ui.section(run_head(r), { ui.text(meta), jobs_table(s, r) }))
	end
	return ui.card("Running", children, { icon = "activity", meta = if #active > 0 then tostring(#active) else nil })
end

local function finished_view(s: State): any
	local rows = {}
	for _, r in finished_runs(s) do
		local started = parse_time(r.run_started_at)
		local finished = parse_time(r.updated_at)
		table.insert(rows, {
			id = tostring(r.id),
			menu = { "Open run" },
			cells = {
				{ text = label_of(r.status, r.conclusion), dot = tone_of(r.status, r.conclusion) },
				{ ui.span(r.name or "workflow", "strong") },
				{ ui.link(r.display_title, r.html_url) },
				{ ui.span(r.head_branch or "", "mono muted") },
				ago(finished),
				duration(started, finished),
			},
		})
	end
	return ui.card("Recently finished", {
		keyed(
			ui.table({
				{ id = "status", head = "Status", priority = 4 },
				{ id = "workflow", head = "Workflow", priority = 3 },
				{ id = "title", head = "Title", grow = 1, priority = 5 },
				{ id = "branch", head = "Branch", mono = true, priority = 1 },
				{ id = "when", head = "Finished", priority = 2 },
				{ id = "took", head = "Took", align = "end", priority = 1 },
			}, rows, { selectable = true, empty = "No finished runs" }),
			"finished"
		),
	}, { icon = "list" })
end

local function open_run(s: State, id: string)
	for _, r in s.runs or {} do
		if tostring(r.id) == id then
			s.cx:open(r.html_url)
			return
		end
	end
end

-- Block -------------------------------------------------------------------------------------------

tern.block.define("runs", {
	font = "sans",

	init = function(cx, _args, saved)
		local s: State = {
			cx = cx,
			alive = true,
			jobs = {},
			interval = if saved and type(saved.interval) == "number" then saved.interval else DEFAULT_INTERVAL,
			gen = 0,
			resolve_gen = 0,
			ticks = 0,
		}
		tern.timer(0, function()
			tick(s)
		end)
		return s
	end,

	title = function(s)
		return if s.repo then "Actions · " .. string.match(s.repo.slug, "[^/]+$") else "GitHub Actions"
	end,

	save = function(s)
		return { interval = s.interval }
	end,

	view = function(s, _cx)
		local children = { toolbar(s), repo_line(s) }
		if s.repo_error then
			table.insert(children, ui.text(ui.span(s.repo_error, "muted")))
		elseif s.runs_error then
			table.insert(children, ui.text(ui.span("GitHub: " .. s.runs_error, "error")))
		end
		if s.repo then
			if s.runs then
				table.insert(children, running_view(s))
				table.insert(children, finished_view(s))
			elseif not s.runs_error then
				table.insert(children, ui.progress(nil, "Loading workflow runs…"))
			end
		end
		return { main = ui.col(children) }
	end,

	key = function(s, key, _cx)
		if key.name == "r" and not (key.ctrl or key.meta or key.alt) then
			requery(s)
			return true
		end
		return false
	end,

	event = function(s, ev, cx)
		if ev.ev ~= "action" and ev.ev ~= "activate" then
			return
		end
		if ev.act == "refresh" then
			requery(s)
		elseif ev.act == "interval" and ev.value then
			local m = tonumber(ev.value)
			if m and m ~= s.interval then
				s.interval = m
				if s.updated then
					s.next_fetch = if m > 0 then (s.updated :: number) + m * 60 else nil
				end
				cx:save()
			end
		elseif ev.item and ev.id == "finished" then
			open_run(s, ev.item)
		elseif ev.item and type(ev.id) == "string" and string.sub(ev.id, 1, 5) == "jobs-" then
			cx:open(ev.item)
		end
	end,
})
