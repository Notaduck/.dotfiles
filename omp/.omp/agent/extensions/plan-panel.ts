// Plan panel: the session's todo list (what the agent keeps with the `todo` tool) in a panel on the
// left edge of the TUI. Ctrl+\ or `/plan-panel` toggles it; the choice is kept in
// <agentDir>/plan-panel.json so it survives restarts.
//
// The panel is a non-modal overlay anchored top-left: it draws over the left columns of the live
// viewport (the transcript does not reflow around it), never takes keyboard focus, stops above the
// prompt, and steps aside while a caret-less selector or dialog has focus. Under Tern's native
// surface protocol overlays can only anchor top/center/bottom (pi-tui native/backend.ts,
// `overlayAnchor`), so there the plan is shown as a widget above the editor instead.
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext, ExtensionUIContext } from "@oh-my-pi/pi-coding-agent";
import type { Component, OverlayOptions, Theme, TUI } from "@oh-my-pi/pi-tui";
import { singleLine, truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";
import type { TodoItem, TodoPhase } from "@oh-my-pi/pi-tui/tools/todo";

const SHORTCUT = "ctrl+\\";
const SHORTCUT_LABEL = "Ctrl+\\";
const COMMAND = "plan-panel";
const WIDGET_KEY = "plan-panel";
const SYNC_INTERVAL_MS = 1000;
// Panel width: share of the terminal, clamped. Below these sizes the panel would crowd out the transcript.
const WIDTH_SHARE = 0.28;
const MIN_WIDTH = 30;
const MAX_WIDTH = 42;
const MIN_TERMINAL_COLS = 80;
const MIN_TERMINAL_ROWS = 12;
// Rows left free at the bottom so the panel never covers the prompt editor and status line.
const RESERVED_BOTTOM_ROWS = 8;
// The native-surface fallback widget sits above the editor, so it stays short.
const WIDGET_MAX_ROWS = 10;

interface Row {
	text: string;
	focus?: boolean;
}

interface Progress {
	closed: number;
	total: number;
}

function isClosed(task: TodoItem): boolean {
	return task.status === "completed" || task.status === "abandoned";
}

function progressOf(phases: readonly TodoPhase[]): Progress {
	let closed = 0;
	let total = 0;
	for (const phase of phases) {
		for (const task of phase.tasks) {
			total++;
			if (isClosed(task)) closed++;
		}
	}
	return { closed, total };
}

/** The phase holding the current work: the first with an open task, else the last. */
function currentPhaseIndex(phases: readonly TodoPhase[]): number {
	const open = phases.findIndex(phase => phase.tasks.some(task => !isClosed(task)));
	return open === -1 ? phases.length - 1 : open;
}

/** The task to keep in view: the in-progress one, else the first pending one. */
function focusTask(phases: readonly TodoPhase[]): TodoItem | undefined {
	let firstPending: TodoItem | undefined;
	for (const phase of phases) {
		for (const task of phase.tasks) {
			if (task.status === "in_progress") return task;
			if (!firstPending && task.status === "pending") firstPending = task;
		}
	}
	return firstPending;
}

function taskRow(theme: Theme, task: TodoItem, width: number, focused: boolean): Row {
	const indent = "  ";
	let marker: string;
	switch (task.status) {
		case "completed":
			marker = theme.fg("success", theme.checkbox.checked);
			break;
		case "in_progress":
			marker = theme.fg("accent", theme.nav.cursor);
			break;
		case "blocked":
			marker = theme.fg("warning", theme.status.warning);
			break;
		case "abandoned":
			marker = theme.fg("error", theme.status.aborted);
			break;
		default:
			marker = theme.fg(focused ? "accent" : "dim", theme.checkbox.unchecked);
	}
	const label =
		task.status === "blocked" ? `${task.content} (${task.blocker ? `blocked: ${task.blocker}` : "blocked"})` : task.content;
	const room = Math.max(1, width - visibleWidth(indent) - visibleWidth(marker) - 1);
	const text = truncateToWidth(singleLine(label), room);
	let styled: string;
	switch (task.status) {
		case "completed":
			styled = theme.fg("muted", text);
			break;
		case "in_progress":
			styled = theme.bold(theme.fg("accent", text));
			break;
		case "blocked":
			styled = theme.fg("warning", text);
			break;
		case "abandoned":
			styled = theme.fg("dim", theme.strikethrough(text));
			break;
		default:
			styled = theme.fg(focused ? "accent" : "text", text);
	}
	return { text: `${indent}${marker} ${styled}`, focus: focused };
}

function phaseHeader(theme: Theme, phase: TodoPhase, width: number, current: boolean): Row {
	const done = phase.tasks.filter(isClosed).length;
	const count = ` ${done}/${phase.tasks.length}`;
	const name = truncateToWidth(singleLine(phase.name), Math.max(1, width - count.length));
	const styledName = current ? theme.bold(theme.fg("accent", name)) : theme.fg("muted", name);
	return { text: styledName + theme.fg("dim", count) };
}

/**
 * Phases and tasks as rows no taller than `budget`. Collapses progressively: fully closed phases
 * first, then every phase but the current one, then a window around the in-progress task.
 */
function planRows(theme: Theme, phases: readonly TodoPhase[], width: number, budget: number): Row[] {
	const current = currentPhaseIndex(phases);
	const focus = focusTask(phases);
	const build = (expand: (phase: TodoPhase, index: number) => boolean): Row[] => {
		const rows: Row[] = [];
		phases.forEach((phase, index) => {
			rows.push(phaseHeader(theme, phase, width, index === current));
			if (!expand(phase, index)) return;
			for (const task of phase.tasks) rows.push(taskRow(theme, task, width, task === focus));
		});
		return rows;
	};
	const attempts: Array<(phase: TodoPhase, index: number) => boolean> = [
		() => true,
		phase => phase.tasks.some(task => !isClosed(task)),
		(_phase, index) => index === current,
	];
	let rows: Row[] = [];
	for (const expand of attempts) {
		rows = build(expand);
		if (rows.length <= budget) return rows;
	}
	// Still too tall: keep a window around the focused row, marking what was cut.
	const size = Math.max(1, budget);
	const focusIndex = Math.max(0, rows.findIndex(row => row.focus));
	const start = Math.max(0, Math.min(focusIndex - Math.floor(size / 2), rows.length - size));
	const window = rows.slice(start, start + size);
	const hiddenBelow = rows.length - start - window.length;
	if (start > 0 && window.length > 1) {
		window[0] = { text: theme.fg("dim", `  … ${start + 1} more above`) };
	}
	if (hiddenBelow > 0 && window.length > 1) {
		window[window.length - 1] = { text: theme.fg("dim", `  … ${hiddenBelow + 1} more below`) };
	}
	return window;
}

function progressBar(theme: Theme, progress: Progress, width: number): string {
	const label = ` ${progress.closed}/${progress.total}`;
	const barWidth = Math.max(1, width - label.length);
	const filled = progress.total === 0 ? 0 : Math.round((progress.closed / progress.total) * barWidth);
	return (
		theme.fg("accent", theme.progress.filled.repeat(filled)) +
		theme.fg("dim", theme.progress.empty.repeat(barWidth - filled)) +
		theme.fg(progress.closed === progress.total ? "success" : "muted", label)
	);
}

function readVisible(file: string): boolean {
	try {
		const parsed = JSON.parse(fs.readFileSync(file, "utf8")) as { visible?: unknown };
		return parsed.visible !== false;
	} catch {
		return true;
	}
}

export default function planPanel(pi: ExtensionAPI) {
	const stateFile = path.join(pi.pi.getAgentDir(), "plan-panel.json");
	let visible = readVisible(stateFile);
	let phases: TodoPhase[] = [];
	let version = 0;
	let lastLeafId: string | null | undefined;
	let ui: ExtensionUIContext | undefined;
	let latestCtx: ExtensionContext | undefined;

	let tui: TUI | undefined;
	let panel: PlanPanel | undefined;
	let closePanel: (() => void) | undefined;
	let mounted = false;
	let widgetShown = false;
	let releaseHooks: (() => void) | undefined;
	// Caret row the panel last sized itself against (see PlanPanel.render).
	let sizedForCaretRow: number | undefined;

	class PlanPanel implements Component {
		#cache: { key: string; theme: Theme; lines: string[] } | undefined;

		render(width: number): readonly string[] {
			// With a short transcript the prompt sits mid-screen. The last paint's caret row (screen
			// coordinates) locates it: the editor's top row is one row above its first text line. No caret
			// means a selector or dialog without one has focus; step aside rather than cover it.
			const caretRow = tui?.getDebugPaint()?.cursor?.y;
			sizedForCaretRow = caretRow;
			const th = ui?.theme;
			if (caretRow === undefined || !th || !ui || phases.length === 0) return [];
			const rows = tui?.terminal.rows ?? 24;
			const editorTop = caretRow - ui.getEditorText().split("\n").length;
			const maxRows = Math.min(rows - RESERVED_BOTTOM_ROWS, editorTop - 1);
			// Border, progress bar, border, and at least two plan rows.
			if (maxRows < 5) return [];
			const key = `${width}:${maxRows}:${version}`;
			if (this.#cache?.key === key && this.#cache.theme === th) return this.#cache.lines;

			const box = th.boxRound;
			const border = (s: string) => th.fg("borderMuted", s);
			const inner = Math.max(1, width - 4);
			const row = (content: string) =>
				`${border(box.vertical)} ${truncateToWidth(content, inner, "", true)} ${border(box.vertical)}`;

			const title = th.bold(th.fg("accent", " Plan "));
			const hint = ` ${SHORTCUT_LABEL} hides `;
			const top = `${border(box.topLeft + box.horizontal)}${title}${border(box.horizontal.repeat(Math.max(0, width - 3 - visibleWidth(title))) + box.topRight)}`;
			const bottomFill = width - 2 - hint.length;
			const bottom =
				bottomFill >= 2
					? border(box.bottomLeft + box.horizontal) +
						th.fg("dim", hint) +
						border(box.horizontal.repeat(bottomFill - 1) + box.bottomRight)
					: border(box.bottomLeft + box.horizontal.repeat(Math.max(0, width - 2)) + box.bottomRight);

			const budget = maxRows - 3;
			const lines = [top, row(progressBar(th, progressOf(phases), inner))];
			for (const r of planRows(th, phases, inner, budget)) lines.push(row(r.text));
			lines.push(bottom);
			this.#cache = { key, theme: th, lines };
			return lines;
		}

		invalidate(): void {
			this.#cache = undefined;
		}
	}

	class PlanWidget implements Component {
		#cache: { key: string; theme: Theme; lines: string[] } | undefined;

		render(width: number): readonly string[] {
			const th = ui?.theme;
			if (!th || phases.length === 0) return [];
			const key = `${width}:${version}`;
			if (this.#cache?.key === key && this.#cache.theme === th) return this.#cache.lines;
			const inner = Math.max(1, width - 2);
			const lines = [` ${th.bold(th.fg("accent", "Plan "))}${progressBar(th, progressOf(phases), Math.max(1, inner - 5))}`];
			for (const r of planRows(th, phases, inner, WIDGET_MAX_ROWS - 1)) lines.push(` ${r.text}`);
			this.#cache = { key, theme: th, lines };
			return lines;
		}

		invalidate(): void {
			this.#cache = undefined;
		}
	}

	const isShowing = (cols: number, rows: number) =>
		visible &&
		phases.length > 0 &&
		tui?.nativeRendering !== true &&
		cols >= MIN_TERMINAL_COLS &&
		rows >= MIN_TERMINAL_ROWS;

	const overlayOptions: OverlayOptions = {
		anchor: "top-left",
		margin: 0,
		maxHeight: "100%",
		get width() {
			const cols = tui?.terminal.columns ?? 100;
			return Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, Math.round(cols * WIDTH_SHARE)));
		},
		visible: isShowing,
	};

	const requestRender = () => {
		panel?.invalidate();
		tui?.requestRender();
	};

	/**
	 * Keep the overlay from holding keys or blocking the shortcuts gated on `hasOverlay()`, and resize it
	 * when the prompt moves.
	 */
	const makePassive = () => {
		if (!tui || !panel) return;
		const t = tui;
		const own = panel;
		const entry = t.overlayStack.find(e => e.component === own);
		if (!entry) return;
		// A released overlay stays painted but no longer holds the keys (pi-tui `overlayStack.released`).
		entry.released = true;
		if (t.getFocused() === own) t.setFocus(entry.preFocus);
		// Input-controller shortcuts (Ctrl+R history, Ctrl+O expand, external editor, ...) bail out while
		// any overlay is visible; this one is not modal, so leave it out of that check.
		const original = t.hasOverlay;
		const patched = function (this: TUI): boolean {
			if (entry.hidden) return original.call(this);
			entry.hidden = true;
			try {
				return original.call(this);
			} finally {
				entry.hidden = false;
			}
		};
		t.hasOverlay = patched;
		// The panel is sized from the previous paint's caret; repaint once more when that paint moved it.
		const removePaintListener = t.addPaintListener(() => {
			if (!isShowing(t.terminal.columns, t.terminal.rows)) return;
			if (t.getDebugPaint()?.cursor?.y !== sizedForCaretRow) t.requestRender();
		});
		releaseHooks = () => {
			if (t.hasOverlay === patched) t.hasOverlay = original;
			removePaintListener();
			releaseHooks = undefined;
		};
	};

	const mount = (ctx: ExtensionContext) => {
		if (mounted) return;
		mounted = true;
		ctx.ui
			.custom<void>(
				(t, _theme, _keybindings, done) => {
					tui = t;
					panel = new PlanPanel();
					closePanel = () => done(undefined);
					return panel;
				},
				{ overlay: true, overlayOptions, onHandle: makePassive },
			)
			.catch(err => pi.logger.warn("plan-panel: overlay failed", { err: String(err) }))
			.finally(() => {
				releaseHooks?.();
				mounted = false;
				panel = undefined;
				closePanel = undefined;
			});
	};

	/** Under Tern's native surface the overlay cannot dock left; show the plan above the editor. */
	const syncWidget = (ctx: ExtensionContext) => {
		const want = visible && phases.length > 0 && tui?.nativeRendering === true;
		if (want === widgetShown) return;
		widgetShown = want;
		ctx.ui.setWidget(WIDGET_KEY, want ? () => new PlanWidget() : undefined, { placement: "aboveEditor" });
	};

	const setPhases = (ctx: ExtensionContext, next: TodoPhase[]) => {
		if (JSON.stringify(next) === JSON.stringify(phases)) return;
		phases = next;
		version++;
		syncWidget(ctx);
		requestRender();
	};

	/** Re-read the latest todo snapshot from the branch when it has grown or moved. */
	const syncFromBranch = (ctx: ExtensionContext) => {
		const leafId = ctx.sessionManager.getLeafId();
		if (leafId === lastLeafId) return;
		lastLeafId = leafId;
		setPhases(ctx, pi.pi.getLatestTodoPhasesFromEntries(ctx.sessionManager.getBranch()));
	};

	const active = (ctx: ExtensionContext) => ctx.mode === "tui" && ctx.hasUI && ctx.agent.kind === "main";

	const track = (ctx: ExtensionContext) => {
		latestCtx = ctx;
		ui = ctx.ui;
	};

	const toggle = (ctx: ExtensionContext, next = !visible) => {
		if (!active(ctx)) return;
		track(ctx);
		visible = next;
		try {
			fs.writeFileSync(stateFile, `${JSON.stringify({ visible })}\n`);
		} catch (err) {
			pi.logger.warn("plan-panel: could not save state", { err: String(err) });
		}
		mount(ctx);
		syncWidget(ctx);
		requestRender();
		const note = phases.length === 0 ? " (no todos yet)" : "";
		ctx.ui.notify(`Plan panel ${visible ? "shown" : "hidden"}${note}`, "info");
	};

	pi.registerShortcut(SHORTCUT, {
		description: "Toggle the plan panel",
		handler: ctx => toggle(ctx),
	});

	pi.registerCommand(COMMAND, {
		description: "Toggle the plan panel (show | hide)",
		getArgumentCompletions: prefix =>
			["show", "hide"].filter(v => v.startsWith(prefix)).map(v => ({ value: v, label: v })),
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();
			if (arg && arg !== "show" && arg !== "hide") {
				ctx.ui.notify(`Usage: /${COMMAND} [show|hide]`, "warning");
				return;
			}
			toggle(ctx, arg === "" ? !visible : arg === "show");
		},
	});

	pi.on("session_start", (_event, ctx) => {
		if (!active(ctx)) return;
		track(ctx);
		lastLeafId = undefined;
		syncFromBranch(ctx);
		mount(ctx);
		// Catches todo edits outside the tool (`/todo`, eval bridge) and Tern's late native/rows decision.
		ctx.setInterval(() => {
			if (!latestCtx) return;
			syncFromBranch(latestCtx);
			syncWidget(latestCtx);
		}, SYNC_INTERVAL_MS);
	});

	const resync = (_event: unknown, ctx: ExtensionContext) => {
		if (!active(ctx)) return;
		track(ctx);
		lastLeafId = undefined;
		syncFromBranch(ctx);
	};
	pi.on("session_switch", resync);
	pi.on("session_branch", resync);
	pi.on("session_tree", resync);
	pi.on("session_compact", resync);
	pi.on("turn_end", (_event, ctx) => {
		if (!active(ctx)) return;
		track(ctx);
		syncFromBranch(ctx);
	});

	pi.on("tool_result", (event, ctx) => {
		if (event.toolName !== "todo" || !active(ctx)) return;
		track(ctx);
		// The result lands on the branch only after this event; take the committed phases straight away.
		const committed = pi.pi.committedTodoPhases({
			content: event.content,
			details: event.details,
			isError: event.isError,
		});
		if (committed) setPhases(ctx, committed);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (widgetShown && ctx.hasUI) ctx.ui.setWidget(WIDGET_KEY, undefined);
		widgetShown = false;
		closePanel?.();
		releaseHooks?.();
		latestCtx = undefined;
	});
}
