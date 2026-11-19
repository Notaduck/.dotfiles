-- The animal roaming the Work block's dock: truecolor half-block pixel art (two pixels per cell, `▀`/`▄`
-- with foreground and background colors) in a `tern.ui.ansi` mini terminal. Each animal has a four-frame
-- walk cycle and idle frames (stand, blink, talk, and the capybara's ear twitch); left-facing frames are
-- the right-facing ones mirrored. Frames are rendered to ANSI once and cached.

local ui = tern.ui

export type Pet = {
	x: number,
	dir: number,
	step: number,
	-- Ticks left to stand still.
	rest: number,
	say: string?,
	say_until: number,
}

local M = {}

M.TICK_MS = 180
M.ANIMALS = { "duck", "capybara", "off" }
M.LABEL = { duck = "Duck", capybara = "Capybara", off = "No pet" }

local SAYINGS = {
	duck = { "quack!", "quack?", "*waddle*", "ship it" },
	capybara = { "ok i pull up", "*munch*", "chill", "no stress" },
}

-- Pixel colors by letter; "." is transparent.
local PALETTES = {
	duck = {
		Y = { 247, 201, 72 },
		y = { 222, 166, 44 },
		O = { 242, 140, 40 },
		o = { 226, 112, 26 },
		K = { 30, 30, 34 },
	},
	capybara = {
		B = { 160, 112, 63 },
		b = { 111, 74, 40 },
		n = { 58, 42, 30 },
		K = { 26, 26, 26 },
		e = { 125, 85, 48 },
	},
}

-- Right-facing pixel rows: the body, then the leg rows of each walk phase.
local DUCK_BODY = {
	"......YYYY......",
	".....YYYYYY.....",
	".....YYYYKYY....",
	".....YYYYYYOOO..",
	"......YYYYYOO...",
	".......YYYY.....",
	"Y.....YYYYYY....",
	"YY..YYYYYYYYY...",
	"YYYYYYyyyyYYYY..",
	".YYYYYyyyyyYYY..",
	"..YYYYYyyyYYYY..",
	"...YYYYYYYYYY...",
}
local DUCK_LEGS = {
	{ "......o..o......", ".....oo.oo......" },
	{ ".....o....o.....", "....oo....oo...." },
	{ "......o..o......", "......oo.oo....." },
	{ ".......oo.......", "......oooo......" },
}
local CAPY_BODY = {
	"..................ee..",
	"....BBBBBBBBBBBBBBBB..",
	"..BBBBBBBBBBBBBBBBBBB.",
	".BBBBBBBBBBBBBBBBBKBBB",
	".BBBBBBBBBBBBBBBBBBBBn",
	"BBBBBBBBBBBBBBBBBBBBBn",
	"BBBBBBBBBBBBBBBBBBBBB.",
	".BBBBBBBbbbbbBBBBBBB..",
	"..bBBBBBBBBBBBBBBBb...",
}
local CAPY_LEGS = {
	{ "...bb..........bb.....", "...bb..........bb.....", "...bbb.........bbb...." },
	{ "...bb..........bb.....", "....bb........bb......", "....bbb.......bbb....." },
	{ "...bb..........bb.....", "..bb............bb....", "..bbb...........bbb..." },
	{ "...bb..........bb.....", "....bb........bb......", "....bbb.......bbb....." },
}

local function with(rows: { string }, changes: { [number]: string }?): { string }
	local out = table.clone(rows)
	for i, row in changes or {} do
		out[i] = row
	end
	return out
end

local function frame(body: { string }, legs: { string }, changes: { [number]: string }?): { string }
	local out = with(body, changes)
	for _, row in legs do
		table.insert(out, row)
	end
	return out
end

-- Pixel frames by name. Row indexes in `changes` are 1-based body rows.
local FRAMES = {
	duck = {
		walk1 = frame(DUCK_BODY, DUCK_LEGS[1]),
		walk2 = frame(DUCK_BODY, DUCK_LEGS[2]),
		walk3 = frame(DUCK_BODY, DUCK_LEGS[3]),
		walk4 = frame(DUCK_BODY, DUCK_LEGS[4]),
		stand = frame(DUCK_BODY, DUCK_LEGS[1]),
		blink = frame(DUCK_BODY, DUCK_LEGS[1], { [3] = ".....YYYYyYY...." }),
		talk = frame(DUCK_BODY, DUCK_LEGS[1], { [4] = ".....YYYYYYOOOO.", [5] = "......YYYYY..OO." }),
	},
	capybara = {
		walk1 = frame(CAPY_BODY, CAPY_LEGS[1]),
		walk2 = frame(CAPY_BODY, CAPY_LEGS[2]),
		walk3 = frame(CAPY_BODY, CAPY_LEGS[3]),
		walk4 = frame(CAPY_BODY, CAPY_LEGS[4]),
		stand = frame(CAPY_BODY, CAPY_LEGS[1]),
		blink = frame(CAPY_BODY, CAPY_LEGS[1], { [4] = ".BBBBBBBBBBBBBBBBBbBBB" }),
		talk = frame(CAPY_BODY, CAPY_LEGS[1], {
			[5] = ".BBBBBBBBBBBBBBBBBBBBB",
			[6] = "BBBBBBBBBBBBBBBBBBBBBn",
			[7] = "BBBBBBBBBBBBBBBBBBBBn.",
		}),
		ear = frame(CAPY_BODY, CAPY_LEGS[1], { [1] = ".................e.e.." }),
	},
}

local ESC = "\27["

local function fg(c: { number }): string
	return string.format("%s38;2;%d;%d;%dm", ESC, c[1], c[2], c[3])
end

local function bg(c: { number }?): string
	return if c then string.format("%s48;2;%d;%d;%dm", ESC, c[1], c[2], c[3]) else ESC .. "49m"
end

-- Two pixel rows as one line of half blocks; colors change only where they must.
local function cells(top: string, bottom: string, palette: { [string]: { number } }): string
	local out = {}
	local cur_fg, cur_bg = "", ESC .. "49m"
	local function put(f: string?, b: string, ch: string)
		if f and f ~= cur_fg then
			table.insert(out, f)
			cur_fg = f
		end
		if b ~= cur_bg then
			table.insert(out, b)
			cur_bg = b
		end
		table.insert(out, ch)
	end
	for i = 1, #top do
		local t, b = palette[string.sub(top, i, i)], palette[string.sub(bottom, i, i)]
		if not t and not b then
			put(nil, bg(nil), " ")
		elseif t and not b then
			put(fg(t), bg(nil), "▀")
		elseif b and not t then
			put(fg(b), bg(nil), "▄")
		elseif t == b then
			put(fg(t :: { number }), bg(nil), "█")
		else
			put(fg(t :: { number }), bg(b), "▀")
		end
	end
	table.insert(out, ESC .. "0m")
	return table.concat(out)
end

local function render(rows: { string }, palette: { [string]: { number } }): { string }
	local lines = {}
	for i = 1, #rows, 2 do
		table.insert(lines, cells(rows[i], rows[i + 1] or string.rep(".", #rows[i]), palette))
	end
	return lines
end

-- cache[animal][name][dir] = ANSI lines
local cache: { [string]: { [string]: { [number]: { string } } } } = {}
for animal, frames in FRAMES do
	cache[animal] = {}
	for name, rows in frames do
		local left = {}
		for i, row in rows do
			left[i] = string.reverse(row)
		end
		cache[animal][name] = { [1] = render(rows, PALETTES[animal]), [-1] = render(left, PALETTES[animal]) }
	end
end

local function width(animal: string): number
	return #FRAMES[animal].stand[1]
end

function M.valid(animal: any): boolean
	return animal == "off" or FRAMES[animal] ~= nil
end

function M.new(): Pet
	return { x = 0, dir = 1, step = 0, rest = 0, say = nil, say_until = 0 }
end

-- One tick: walk a cell, or stand (and sometimes look the other way, or say something).
function M.step(p: Pet, animal: string, cols: number)
	-- The mini terminal's cells are wider than the pane's and it has padding; a line past its edge would wrap.
	local max_x = math.max(0, math.floor(cols * 0.8) - width(animal) - 2)
	p.step += 1
	if p.say and p.step > p.say_until then
		p.say = nil
	end
	if p.rest > 0 then
		p.rest -= 1
		if math.random() < 0.03 then
			p.dir = -p.dir
		end
		return
	end
	p.x += p.dir
	if p.x <= 0 then
		p.x, p.dir = 0, 1
	elseif p.x >= max_x then
		p.x, p.dir = max_x, -1
	end
	local roll = math.random()
	if roll < 0.02 then
		p.rest = math.random(10, 35)
		if math.random() < 0.6 then
			local lines = SAYINGS[animal]
			p.say = lines[math.random(#lines)]
			p.say_until = p.step + 20
		end
	elseif roll < 0.03 then
		p.dir = -p.dir
	end
end

local function frame_name(p: Pet, animal: string): string
	if p.rest == 0 then
		return "walk" .. (p.step % 4 + 1)
	elseif p.say and (p.step // 2) % 2 == 0 then
		return "talk"
	elseif p.step % 23 < 2 then
		return "blink"
	elseif FRAMES[animal].ear and p.step % 37 < 3 then
		return "ear"
	end
	return "stand"
end

function M.view(p: Pet, animal: string): any
	local lines = cache[animal][frame_name(p, animal)][p.dir]
	local pad = string.rep(" ", p.x)
	local bubble_at = p.x + (if p.dir > 0 then width(animal) - 4 else 0)
	local out = { string.rep(" ", bubble_at) .. ESC .. "2m" .. (p.say or "") .. ESC .. "0m" }
	for _, line in lines do
		table.insert(out, pad .. line)
	end
	-- A region's root is never drawn, only its children.
	return ui.col({ ui.ansi(table.concat(out, "\n")) })
end

return M
