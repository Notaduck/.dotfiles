--[[
Quokka-style inline evaluation for JS/TS buffers.

Top-level declarations and expression statements are instrumented via treesitter,
the result runs in Node (with core/node_eval_prelude.mjs preloaded), and values,
console output and errors are shown as virtual text at the end of each line.

Commands: :NodeEval, :NodeEvalLive (toggle run-on-change), :NodeEvalClear, :NodeScratch [ts]
]]
local M = {}

local ns = vim.api.nvim_create_namespace("node_eval")
local prelude = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "node_eval_prelude.mjs")
local MARK = "\0NODE_EVAL\0"
local TIMEOUT_MS = 5000
local DEBOUNCE_MS = 250
local MAX_WIDTH = 120

local extensions = { javascript = "mjs", typescript = "mts" }

---@type table<integer, { gen: integer, job?: vim.SystemObj, timer?: uv.uv_timer_t, live?: boolean }>
local state = {}

local function buf_state(buf)
	state[buf] = state[buf] or { gen = 0 }
	return state[buf]
end

vim.api.nvim_set_hl(0, "NodeEvalValue", { default = true, link = "Comment" })
vim.api.nvim_set_hl(0, "NodeEvalLog", { default = true, link = "DiagnosticInfo" })
vim.api.nvim_set_hl(0, "NodeEvalError", { default = true, link = "DiagnosticError" })

-- Identifiers bound by a declarator name (handles destructuring, skips default values).
local function bound_names(node, buf, out)
	local t = node:type()
	if t == "identifier" or t == "shorthand_property_identifier_pattern" then
		table.insert(out, vim.treesitter.get_node_text(node, buf))
	elseif t == "assignment_pattern" or t == "object_assignment_pattern" then
		bound_names(node:field("left")[1], buf, out)
	elseif t == "pair_pattern" then
		bound_names(node:field("value")[1], buf, out)
	else
		for child in node:iter_children() do
			if child:named() then
				bound_names(child, buf, out)
			end
		end
	end
	return out
end

-- Returns the buffer's source with instrumentation spliced in. Lines are never added
-- or removed, so line numbers in stack traces map 1:1 to the buffer.
local function instrument(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return lines
	end
	local root = parser:parse()[1]:root()

	local edits = {} -- { row, col, text }
	for stmt in root:iter_children() do
		local node = stmt
		if node:type() == "export_statement" and node:field("declaration")[1] then
			node = node:field("declaration")[1]
		end
		local t = node:type()

		if t == "lexical_declaration" or t == "variable_declaration" then
			local names = {}
			for child in node:iter_children() do
				if child:type() == "variable_declarator" then
					bound_names(child:field("name")[1], buf, names)
				end
			end
			if #names > 0 then
				local er, ec = stmt:end_()
				local quoted = vim.tbl_map(function(n)
					return string.format("%q", n)
				end, names)
				table.insert(edits, {
					er,
					ec,
					string.format(";__ne(%d,[%s],[%s]);", er, table.concat(quoted, ","), table.concat(names, ",")),
				})
			end
		elseif t == "expression_statement" then
			local expr = node:named_child(0)
			if expr then
				local sr, sc, er, ec = expr:range()
				table.insert(edits, { er, ec, "))" })
				table.insert(edits, { sr, sc, string.format("__nev(%d,(", er) })
			end
		end
	end

	-- Apply back to front so earlier byte columns stay valid.
	table.sort(edits, function(a, b)
		return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2])
	end)
	for _, e in ipairs(edits) do
		local row, col, text = e[1] + 1, e[2], e[3]
		lines[row] = lines[row]:sub(1, col) .. text .. lines[row]:sub(col + 1)
	end
	return lines
end

local function truncate(s)
	s = s:gsub("\n", " ")
	if vim.fn.strdisplaywidth(s) > MAX_WIDTH then
		s = vim.fn.strcharpart(s, 0, MAX_WIDTH - 1) .. "…"
	end
	return s
end

local function render(buf, results)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local last = vim.api.nvim_buf_line_count(buf) - 1
	local by_line = {}
	for _, r in ipairs(results) do
		local row = math.max(0, math.min(r.line or 0, last))
		by_line[row] = by_line[row] or {}
		table.insert(by_line[row], r)
	end
	for row, items in pairs(by_line) do
		local hl, prefix, texts = "NodeEvalValue", "// ", {}
		for _, r in ipairs(items) do
			if r.kind == "error" then
				hl, prefix = "NodeEvalError", "✗ "
			elseif r.kind == "log" and hl ~= "NodeEvalError" then
				hl = "NodeEvalLog"
			end
			table.insert(texts, r.text)
		end
		if #texts > 10 then
			texts = vim.list_extend(vim.list_slice(texts, 1, 10), { "…" })
		end
		vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
			virt_text = { { "  " .. prefix .. truncate(table.concat(texts, " | ")), hl } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
	end
end

function M.clear(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.run(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local ext = extensions[vim.bo[buf].filetype]
	if not ext then
		vim.notify("NodeEval: only javascript/typescript buffers are supported", vim.log.levels.WARN)
		return
	end

	local s = buf_state(buf)
	s.gen = s.gen + 1
	local gen = s.gen
	if s.job then
		s.job:kill(9)
	end

	local name = vim.api.nvim_buf_get_name(buf)
	local base = name ~= "" and name or vim.fs.joinpath(vim.fn.getcwd(), "scratch." .. ext)
	local tmp = vim.fn.tempname() .. "." .. ext
	vim.fn.writefile(instrument(buf), tmp)

	s.job = vim.system({ "node", "--no-warnings", "--import", prelude, tmp }, {
		cwd = vim.fs.dirname(base),
		env = { NODE_EVAL_FILE = tmp, NODE_EVAL_BASE = base },
		timeout = TIMEOUT_MS,
		text = true,
	}, function(res)
		vim.schedule(function()
			os.remove(tmp)
			if not vim.api.nvim_buf_is_valid(buf) or buf_state(buf).gen ~= gen then
				return
			end
			s.job = nil

			local results, has_error = {}, false
			for line in (res.stdout or ""):gmatch("[^\n]+") do
				if vim.startswith(line, MARK) then
					local ok, r = pcall(vim.json.decode, line:sub(#MARK + 1))
					if ok then
						has_error = has_error or r.kind == "error"
						table.insert(results, r)
					end
				end
			end
			if res.signal == 15 then
				table.insert(results, { line = 0, kind = "error", text = ("timed out after %dms"):format(TIMEOUT_MS) })
			elseif res.code ~= 0 and not has_error then
				local msg = vim.trim(res.stderr or ""):match("[^\n]*Error[^\n]*") or ("node exited with code " .. res.code)
				table.insert(results, { line = 0, kind = "error", text = msg })
			end
			render(buf, results)
		end)
	end)
end

local function schedule_run(buf)
	local s = buf_state(buf)
	s.timer = s.timer or vim.uv.new_timer()
	s.timer:stop()
	s.timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
		if vim.api.nvim_buf_is_valid(buf) and s.live then
			M.run(buf)
		end
	end))
end

function M.set_live(buf, enabled)
	buf = buf or vim.api.nvim_get_current_buf()
	local s = buf_state(buf)
	s.live = enabled
	local group = vim.api.nvim_create_augroup("node_eval_live_" .. buf, { clear = true })
	if not enabled then
		M.clear(buf)
		return
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = group,
		buffer = buf,
		callback = function()
			schedule_run(buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			if s.timer then
				s.timer:close()
			end
			if s.job then
				s.job:kill(9)
			end
			state[buf] = nil
		end,
	})
	M.run(buf)
end

function M.toggle_live(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local enabled = not buf_state(buf).live
	M.set_live(buf, enabled)
	vim.notify("NodeEval live " .. (enabled and "on" or "off"))
end

-- Persistent playground file per language, opened with live eval on.
function M.scratch(lang)
	local ext = lang == "ts" and "ts" or "js"
	local dir = vim.fs.joinpath(vim.fn.stdpath("data"), "node-scratch")
	vim.fn.mkdir(dir, "p")
	vim.cmd.edit(vim.fs.joinpath(dir, "scratch." .. ext))
	M.set_live(vim.api.nvim_get_current_buf(), true)
end

vim.api.nvim_create_user_command("NodeEval", function()
	M.run()
end, { desc = "Evaluate buffer with Node and show inline results" })
vim.api.nvim_create_user_command("NodeEvalLive", function()
	M.toggle_live()
end, { desc = "Toggle live Node evaluation for buffer" })
vim.api.nvim_create_user_command("NodeEvalClear", function()
	M.clear()
end, { desc = "Clear inline Node results" })
vim.api.nvim_create_user_command("NodeScratch", function(o)
	M.scratch(o.args)
end, { nargs = "?", complete = function() return { "js", "ts" } end, desc = "Open Node scratchpad" })

vim.keymap.set("n", "<leader>rr", M.run, { desc = "Eval buffer (Node)" })
vim.keymap.set("n", "<leader>rl", M.toggle_live, { desc = "Toggle live eval" })
vim.keymap.set("n", "<leader>rc", M.clear, { desc = "Clear eval results" })
vim.keymap.set("n", "<leader>rs", function() M.scratch("js") end, { desc = "JS scratchpad" })
vim.keymap.set("n", "<leader>rt", function() M.scratch("ts") end, { desc = "TS scratchpad" })

return M
