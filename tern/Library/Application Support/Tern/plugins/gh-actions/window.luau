-- Publishes the focused pane's directory under kv "cwd"; the host block follows it. Plugin blocks
-- (this one included) are skipped so focusing them keeps the last folder.

local function publish(cx, pane: number?)
	if not pane then
		return
	end
	local info = cx.session:pane(pane)
	if not info or info.kind == "plugin" or not info.cwd or info.cwd == "" then
		return
	end
	if tern.kv.get("cwd") ~= info.cwd then
		tern.kv.set("cwd", info.cwd)
	end
end

-- window_start doesn't run again on plugin reload; publish once on load too.
tern.timer(0, function(cx)
	if cx then
		publish(cx, cx.session:focused())
	end
end)

tern.on("window_start", function(cx)
	publish(cx, cx.session:focused())
end)

tern.on("focus", function(ev, cx)
	publish(cx, ev.pane)
end)

tern.on("cwd", function(ev, cx)
	if ev.pane == cx.session:focused() then
		publish(cx, ev.pane)
	end
end)

tern.command({
	id = "open",
	title = "GitHub Actions",
	icon = "activity",
	keys = { "ctrl+b>g" },
	run = function(cx)
		for _, p in cx.session:panes() do
			if p.block == "gh-actions.runs" then
				if p.parked then
					cx.layout:unpark(p.pane)
				else
					cx.layout:focus(p.pane)
				end
				return
			end
		end
		cx:new_block("gh-actions.runs")
	end,
})
