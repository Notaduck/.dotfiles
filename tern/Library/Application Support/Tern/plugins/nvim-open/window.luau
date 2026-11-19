-- File links clicked in terminal output (omp replies, compiler errors, `rg` hits) open in nvim in a
-- split right of the clicked pane, at the link's line and column. One nvim per tab: later clicks in
-- that tab load the file into the same nvim over its --listen socket.
--
-- Everything else keeps Tern's built-in open: the Files tree, palette, drops and `tern open`
-- (EDITOR='tern open --wait'), folders, files on another host, and the kinds Tern has real views for.

local NVIM = "/opt/homebrew/bin/nvim"

-- Databases, notebooks, Markdown (preview, board), canvases, images, PDFs, media, archives.
local TERN_KINDS = {}
for _, ext in {
	"sqlite", "sqlite3", "db", "db3", "s3db", "sl3", "duckdb",
	"ipynb",
	"md", "markdown",
	"canvas", "excalidraw",
	"png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "tif", "tiff", "heic", "avif", "svg",
	"pdf",
	"mp4", "mov", "webm", "mkv", "mp3", "wav", "m4a", "flac", "ogg",
	"zip", "gz", "tgz", "tar", "7z", "rar", "dmg",
} do
	TERN_KINDS[ext] = true
end

local ROUTED_ORIGINS = { link = true }

-- tab id -> { pane, sock } of the nvim this plugin started there.
local editors: { [number]: { pane: number, sock: string } } = {}

local function shell_quote(s: string): string
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

local function vim_string(s: string): string
	return "'" .. (s:gsub("'", "''")) .. "'"
end

local function tern_handles(path: string): boolean
	local ext = path:match("%.([%w]+)$")
	if ext and TERN_KINDS[ext:lower()] then
		return true
	end
	-- Folders: Tern's Files view. Missing paths: another host's file, or a stale link.
	return not tern.fs.exists(path) or pcall(tern.fs.list, path)
end

local function cursor_cmd(req: OpenRequest): string?
	if not req.line then
		return nil
	end
	return string.format("call cursor(%d, %d)", req.line, req.col or 1)
end

local function spawn(req: OpenRequest, cx: WindowCx)
	local target = cx.session:focused()
	local info = target and cx.session:pane(target)
	local sock = string.format("/tmp/tern-nvim-%d-%d.sock", os.time(), math.random(1, 1e9))
	local args = { NVIM, "--listen", shell_quote(sock) }
	local cursor = cursor_cmd(req)
	if cursor then
		table.insert(args, shell_quote("+" .. cursor))
	end
	table.insert(args, "--")
	table.insert(args, shell_quote(req.path))
	local launch = {
		cwd = info and info.cwd or req.path:match("^(.*)/[^/]*$"),
		command = table.concat(args, " "),
	}

	local pane
	if req.how == "tab" or not target then
		pane = cx.layout:new_tab(launch)
	else
		pane = cx.layout:split(target, if req.how == "below" then "down" else "right", launch, { focus = true })
	end
	local tab = pane and cx.session:tab_of(pane)
	if tab then
		editors[tab] = { pane = pane, sock = sock }
	end
end

-- Loads the file into the tab's nvim; false when there is none left to reuse.
local function reuse(req: OpenRequest, cx: WindowCx): boolean
	local target = cx.session:focused()
	local tab = target and cx.session:tab_of(target)
	local ed = tab and editors[tab]
	if not ed then
		return false
	end
	if not cx.session:pane(ed.pane) or not tern.fs.exists(ed.sock) then
		editors[tab] = nil
		return false
	end

	local cmds = { "drop ' . fnameescape(" .. vim_string(req.path) .. ") . '" }
	local cursor = cursor_cmd(req)
	if cursor then
		table.insert(cmds, cursor)
	end
	-- execute() with a list runs each Ex command; the first one splices in fnameescape()'s result.
	local expr = "execute(['" .. table.concat(cmds, "', '") .. "'])"
	tern.process.run({ NVIM, "--server", ed.sock, "--remote-expr", expr }, { timeout_ms = 3000 }, function(res, cb_cx)
		if res.status ~= 0 and cb_cx then
			tern.log.warn("nvim-open: reuse failed, starting a new nvim", res.stderr)
			editors[tab] = nil
			spawn(req, cb_cx)
		end
	end)
	cx.layout:focus(ed.pane)
	return true
end

tern.route.open(function(req, cx)
	if not ROUTED_ORIGINS[req.origin] then
		return nil
	end
	if req.how == "preview" or req.how == "glimpse" or req.how == "over" or req.how == "replace" then
		return nil
	end
	if tern_handles(req.path) then
		return nil
	end
	if not reuse(req, cx) then
		spawn(req, cx)
	end
	return { handled = true }
end)
