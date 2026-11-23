// Git card: after a turn that changed a git repository, a card docked right above the prompt shows the branch, the
// branch it was made from, the changed files and two actions:
//   View diff          /annotate on everything changed since the base branch (commits, uncommitted and new files);
//                      clicking a file opens the same diff on that file
//   Open pull request  the agent commits what is left, pushes, opens a PR filled from the repo's template and
//                      assigns me; once a PR exists the button opens it in the browser instead
// In Tern's native view these are buttons. In a plain terminal use `/git-card diff [file]` and `/git-card pr`.
// `/git-card` shows the card on demand. The card stays until the next turn starts and is never sent to the model.
//
// The base branch is the one the branch was created from (its reflog), else the closest of origin/HEAD, develop,
// main, master, dev and staging. On a base branch itself the diff is against its upstream and there is no PR button.
import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import type { Component, Theme } from "@oh-my-pi/pi-tui";
import { truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";

const WIDGET_KEY = "git-card";
const FRAME_ROLE = "omp.editor.git-card";
/** Holds the card 20px off the prompt instead of the dock's 14px. */
const GAP_KEY = "git-card-gap";
const BASE_NAMES = ["develop", "main", "master", "dev", "staging"];
const MAX_FILES = 8;
const MAX_UNTRACKED = 2000;
const MAX_COUNTED_BYTES = 1_000_000;
const BRANCH_GLYPH = "\uf418"; // nf-oct-git_branch
const FORK_GLYPH = "\uf126"; // nf-fa-code_fork

type Action = "diff" | "pr";
/** Prefix of a file row's click action; the file's path follows. */
const FILE_ACT = "file:";

interface FileStat {
	path: string;
	added: number;
	deleted: number;
}

interface Repo {
	top: string;
	branch?: string;
	/** Branch name the PR targets, e.g. `develop`. */
	base: string;
	/** Ref the diff is taken against, e.g. `origin/develop`. */
	baseRef: string;
	mergeBase: string;
	/** On a feature branch: a PR can be opened. */
	canPr: boolean;
}

interface Card {
	title: string;
	branch: string;
	base: string;
	canPr: boolean;
	files: FileStat[];
	added: number;
	deleted: number;
	commits: number;
	dirty: boolean;
	pr?: { number: number; url: string };
}

// Tern Surface Protocol nodes, the shape omp's own components describe themselves with.
type Span = { t: string; s?: string };
type NativeNode = { k: string; p?: Record<string, unknown>; c?: NativeNode[]; key?: string };

function node(k: string, p?: Record<string, unknown>, c?: NativeNode[], key?: string): NativeNode {
	return { k, p, c, key };
}

function text(spans: Span[], p: Record<string, unknown> = {}, key?: string): NativeNode {
	return node("text", { ...p, spans }, undefined, key);
}

function button(label: string, act: Action, title: string): NativeNode {
	return node("button", { role: "omp.btn", text: label, title, actions: { click: act } }, undefined, act);
}

function plural(n: number, word: string): string {
	return `${n} ${word}${n === 1 ? "" : "s"}`;
}

function status(card: Card): { label: string; tone: "accent" | "warning" | "success" } {
	if (card.pr) return { label: `PR #${card.pr.number}`, tone: "accent" };
	if (card.dirty) return { label: "Uncommitted", tone: "warning" };
	if (!card.canPr) return { label: "Committed", tone: "success" };
	return { label: "Ready", tone: "success" };
}

function prLabel(card: Card): string {
	return card.pr ? `View PR #${card.pr.number}` : "Open pull request";
}

/** `left` and `right` on one row of `width`, `left` truncated to make room. */
function spread(left: string, right: string, width: number): string {
	const room = width - visibleWidth(right) - 1;
	if (room < 1) return truncateToWidth(left, width);
	const shown = truncateToWidth(left, room);
	return `${shown}${" ".repeat(Math.max(1, width - visibleWidth(shown) - visibleWidth(right)))}${right}`;
}

interface TreeRow {
	/** `├── `, `│   └── `, ... */
	prefix: string;
	name: string;
	file?: FileStat;
}

interface TreeDir {
	dirs: Map<string, TreeDir>;
	files: Map<string, FileStat>;
}

/** `files` laid out the way `tree` prints them: entries sorted by name, directories before their contents. */
function fileTree(files: FileStat[]): TreeRow[] {
	const root: TreeDir = { dirs: new Map(), files: new Map() };
	for (const file of files) {
		const parts = file.path.split("/");
		let dir = root;
		for (const part of parts.slice(0, -1)) {
			let next = dir.dirs.get(part);
			if (!next) dir.dirs.set(part, (next = { dirs: new Map(), files: new Map() }));
			dir = next;
		}
		dir.files.set(parts.at(-1)!, file);
	}
	const rows: TreeRow[] = [];
	const walk = (dir: TreeDir, indent: string) => {
		const names = [...new Set([...dir.dirs.keys(), ...dir.files.keys()])].sort((a, b) => a.localeCompare(b));
		names.forEach((name, i) => {
			const last = i === names.length - 1;
			const prefix = `${indent}${last ? "└── " : "├── "}`;
			const sub = dir.dirs.get(name);
			if (sub) {
				rows.push({ prefix, name });
				walk(sub, `${indent}${last ? "    " : "│   "}`);
			}
			const file = dir.files.get(name);
			if (file) rows.push({ prefix, name, file });
		});
	};
	walk(root, "");
	return rows;
}

/** `diff` from `path`'s file on, the files before it moved to the end, so the diff view opens on `path`. */
function startAt(diff: string, path: string): string {
	const files = diff.split(/^(?=diff --git )/m);
	const at = files.findIndex(file => file.slice(0, file.indexOf("\n")).endsWith(` b/${path}`));
	return at <= 0 ? diff : [...files.slice(at), ...files.slice(0, at)].join("");
}

/** Whether the card shows only its title row; shared by every card of the session so a collapse sticks. */
interface Fold {
	collapsed: boolean;
	set(collapsed: boolean): void;
}

class GitCardView implements Component {
	constructor(
		private readonly card: Card,
		private readonly theme: Theme,
		private readonly fold: Fold,
		private readonly act: (action: Action, path?: string) => void,
	) {}

	render(width: number): string[] {
		const { card, theme } = this;
		const pad = "   ";
		const inner = Math.max(10, width - pad.length - 1);
		const st = status(card);
		const head = spread(
			` ${theme.fg("dim", this.fold.collapsed ? "▸" : "▾")} ${theme.fg("accent", BRANCH_GLYPH)} ${theme.bold(card.title)}`,
			theme.fg(st.tone, st.label),
			width - 1,
		);
		if (this.fold.collapsed) return [truncateToWidth(head, width)];
		const lines = [
			head,
			pad +
				truncateToWidth(
					`${theme.fg("muted", `${FORK_GLYPH} ${card.branch} → ${card.base}`)}  ` +
						`${theme.fg("success", `+${card.added}`)} ${theme.fg("error", `−${card.deleted}`)}  ` +
						theme.fg("muted", plural(card.commits, "commit")),
					inner,
				),
		];
		for (const row of fileTree(card.files.slice(0, MAX_FILES))) {
			const name = theme.fg("dim", row.prefix) + (row.file ? theme.fg("muted", row.name) : theme.fg("accent", row.name));
			const counts = row.file
				? `${theme.fg("success", `+${row.file.added}`)} ${theme.fg("error", `−${row.file.deleted}`)}`
				: "";
			lines.push(pad + spread(name, counts, inner));
		}
		if (card.files.length > MAX_FILES) {
			lines.push(pad + theme.fg("dim", `… ${plural(card.files.length - MAX_FILES, "more file")}`));
		}
		const hints = [`/git-card diff ${theme.fg("dim", "view diff")}`];
		if (card.canPr) hints.push(`/git-card pr ${theme.fg("dim", prLabel(card).toLowerCase())}`);
		lines.push(pad + truncateToWidth(theme.fg("accent", hints.join(theme.fg("dim", "  ·  "))), inner));
		return lines.map(line => truncateToWidth(line, width));
	}

	describe(): NativeNode {
		const { card } = this;
		const st = status(card);
		const head: Span[] = [
			{ t: `${BRANCH_GLYPH} `, s: "accent" },
			{ t: card.title, s: "strong" },
			{ t: " · ", s: "dim" },
			{ t: st.label, s: st.tone },
		];
		// The body stays when collapsed: the omp-git-card Tern plugin glides it shut instead of dropping it.
		const section = node(
			"section",
			{ role: "omp.git-card", head, collapsible: true, collapsed: this.fold.collapsed },
			[this.describeBody()],
			"card",
		);
		// Tern draws every `omp.editor.*` column like the prompt: same width, corner radius, border and padding.
		return node("col", { role: FRAME_ROLE }, [section]);
	}

	/** One `fold` column around the content, the single row the plugin's CSS animates. */
	private describeBody(): NativeNode {
		const { card } = this;
		const files = fileTree(card.files.slice(0, MAX_FILES)).map((row, i) => {
			const name = text(
				[
					// Non-breaking spaces keep the tree's indentation from collapsing.
					{ t: row.prefix.replaceAll(" ", "\u00a0"), s: "mono dim" },
					{ t: row.name, s: row.file ? "mono muted" : "mono accent" },
				],
				{ grow: 1, shrink: 1, truncate: "end", lines: 1 },
				"path",
			);
			if (!row.file) return node("row", { gap: "md", align: "baseline" }, [name], `f${i}`);
			const counts = text([
				{ t: `+${row.file.added}`, s: "mono success" },
				{ t: ` −${row.file.deleted}`, s: "mono error" },
			]);
			return node(
				"row",
				{
					role: "omp.git-card.file",
					gap: "md",
					align: "baseline",
					title: `View the diff of ${row.file.path}`,
					actions: { click: `${FILE_ACT}${row.file.path}` },
				},
				[name, counts],
				`f${i}`,
			);
		});
		if (card.files.length > MAX_FILES) {
			files.push(text([{ t: `… ${plural(card.files.length - MAX_FILES, "more file")}`, s: "dim" }], {}, "more"));
		}
		const actions: NativeNode[] = [
			node("spacer", { grow: 1 }),
			button("View diff", "diff", `Annotate the changes against ${card.base}`),
		];
		if (card.canPr) {
			const title = card.pr ? card.pr.url : `Open a pull request into ${card.base}, assigned to you`;
			actions.push(button(prLabel(card), "pr", title));
		}
		const meta = text(
			[
				{ t: `${FORK_GLYPH} ${card.branch} → ${card.base}`, s: "mono muted" },
				{ t: `  +${card.added}`, s: "mono success" },
				{ t: ` −${card.deleted}`, s: "mono error" },
				{ t: `  ${plural(card.commits, "commit")}`, s: "mono muted" },
			],
			{ truncate: "end", lines: 1 },
			"meta",
		);
		const inner = node(
			"col",
			{ gap: "sm" },
			[
				meta,
				node("col", { role: "omp.git-card.files", gap: "xs" }, files, "files"),
				node("row", { role: "omp.actions", gap: "sm", align: "center" }, actions, "actions"),
			],
			"inner",
		);
		return node("col", {}, [inner], "fold");
	}

	handleNativeEvent(event: { type: string; act?: string; collapsed?: boolean }): void {
		if (event.type === "toggle" && event.collapsed !== undefined) this.fold.set(event.collapsed);
		if (event.type !== "action" || !event.act) return;
		if (event.act === "diff" || event.act === "pr") this.act(event.act);
		else if (event.act.startsWith(FILE_ACT)) this.act("diff", event.act.slice(FILE_ACT.length));
	}

	invalidate(): void {}
}

/** 6px more between the card and the prompt (`sm` spacer); nothing in a plain terminal. */
class DockGap implements Component {
	render(): string[] {
		return [];
	}

	describe(): NativeNode {
		return node("spacer", { size: "sm" });
	}

	invalidate(): void {}
}

function prTemplate(top: string): string | undefined {
	for (const dir of [".github", "", "docs"]) {
		let entries: fs.Dirent[];
		try {
			entries = fs.readdirSync(path.join(top, dir), { withFileTypes: true });
		} catch {
			continue;
		}
		for (const entry of entries) {
			const name = entry.name.toLowerCase();
			if (entry.isFile() && name === "pull_request_template.md") return path.join(dir, entry.name);
			if (entry.isDirectory() && name === "pull_request_template") return `${path.join(dir, entry.name)}/`;
		}
	}
	return undefined;
}

function prPrompt(repo: Repo & { branch: string }): string {
	const template = prTemplate(repo.top);
	return [
		`Open a pull request for \`${repo.branch}\` into \`${repo.base}\`.`,
		"",
		"1. If this work left uncommitted changes, commit them in the repo's commit style (see `git log`). Ask me before committing anything that doesn't belong to this work.",
		`2. Push: \`git push -u origin ${repo.branch}\`.`,
		template
			? `3. Fill in the PR template \`${template}\`: keep its headings and checkboxes, tick only what is true, and write N/A where a section doesn't apply.`
			: "3. There is no PR template: write a short description of what changed and why, and how it was tested.",
		`4. Write the title and description like me (skill://write-like-me). Match the title style of recent PRs (\`gh pr list --state merged --limit 10\`) and keep any Jira key in the branch name exactly as written.`,
		`5. Create it with \`gh pr create --base ${repo.base} --head ${repo.branch} --assignee @me --title … --body-file …\`. If gh can't see the repository, pick the account with access from \`gh auth status\` and prefix \`GH_TOKEN=$(gh auth token --user <account>)\`.`,
		"6. Reply with the PR link.",
	].join("\n");
}

export default function gitCard(pi: ExtensionAPI) {
	// The newest context of this session: native button clicks carry none of their own.
	let liveCtx: ExtensionContext | undefined;
	let before: Promise<string | undefined> | undefined;
	let collapsed = false;

	async function git(cwd: string, args: string[], timeout = 15_000): Promise<string | undefined> {
		const res = await pi.exec("git", ["-c", "core.quotePath=false", ...args], { cwd, timeout });
		return res.code === 0 ? res.stdout : undefined;
	}

	async function untracked(top: string): Promise<string[]> {
		const out = await git(top, ["ls-files", "--others", "--exclude-standard", "-z"]);
		return (out ?? "").split("\0").filter(Boolean).slice(0, MAX_UNTRACKED);
	}

	/** Changes when HEAD, the index, the working tree or an untracked file changes. */
	async function fingerprint(cwd: string): Promise<string | undefined> {
		const top = (await git(cwd, ["rev-parse", "--show-toplevel"]))?.trim();
		if (!top) return undefined;
		const [head, porcelain, diff, files] = await Promise.all([
			git(top, ["rev-parse", "-q", "--verify", "HEAD"]),
			git(top, ["status", "--porcelain=v1", "-z"]),
			git(top, ["diff", "--no-ext-diff", "--no-color", "HEAD"]),
			untracked(top),
		]);
		const hash = createHash("sha1").update(`${head}\0${porcelain}\0${diff}\0`);
		for (const file of files) {
			try {
				hash.update(`${file}:${fs.statSync(path.join(top, file)).mtimeMs}\n`);
			} catch {}
		}
		return hash.digest("hex");
	}

	async function verified(top: string, ref: string): Promise<boolean> {
		return (await git(top, ["rev-parse", "-q", "--verify", `${ref}^{commit}`])) !== undefined;
	}

	/** Of `refs`, the one HEAD is fewest commits ahead of. */
	async function closest(top: string, refs: string[]): Promise<{ ref: string; mergeBase: string; ahead: number } | undefined> {
		let best: { ref: string; mergeBase: string; ahead: number } | undefined;
		for (const ref of refs) {
			if (!(await verified(top, ref))) continue;
			const mergeBase = (await git(top, ["merge-base", ref, "HEAD"]))?.trim();
			if (!mergeBase) continue;
			const ahead = Number((await git(top, ["rev-list", "--count", `${mergeBase}..HEAD`]))?.trim());
			if (!best || ahead < best.ahead) best = { ref, mergeBase, ahead };
		}
		return best;
	}

	/** The branch `branch` was created from, by its reflog or the checkout that first moved onto it. */
	async function branchedFrom(top: string, branch: string): Promise<string | undefined> {
		const created = (await git(top, ["reflog", "show", "--format=%gs", `refs/heads/${branch}`]))?.trim().split("\n").at(-1);
		const from = created?.match(/^branch: Created from (.+)$/)?.[1];
		if (from && from !== "HEAD" && from !== branch) return from.replace(/^refs\/(heads|remotes)\//, "");
		const moves = (await git(top, ["reflog", "show", "--format=%gs", "HEAD"]))?.split("\n") ?? [];
		for (let i = moves.length - 1; i >= 0; i--) {
			const move = moves[i].match(/^checkout: moving from (\S+) to (\S+)$/);
			if (move && move[2] === branch && move[1] !== branch && !/^[0-9a-f]{7,40}$/.test(move[1])) return move[1];
		}
		return undefined;
	}

	async function inspect(cwd: string): Promise<Repo | undefined> {
		const top = (await git(cwd, ["rev-parse", "--show-toplevel"]))?.trim();
		if (!top || !(await verified(top, "HEAD"))) return undefined;
		const branch = (await git(top, ["branch", "--show-current"]))?.trim() || undefined;
		const originHead = (await git(top, ["symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"]))
			?.trim()
			.replace(/^origin\//, "");
		const names = [...new Set([...(originHead ? [originHead] : []), ...BASE_NAMES])];

		if (branch && names.includes(branch)) {
			const upstream = (await git(top, ["rev-parse", "--abbrev-ref", "@{upstream}"]))?.trim();
			const found = upstream ? await closest(top, [upstream]) : undefined;
			const mergeBase = found?.mergeBase ?? (await git(top, ["rev-parse", "HEAD"]))!.trim();
			return { top, branch, base: upstream ?? branch, baseRef: upstream ?? "HEAD", mergeBase, canPr: false };
		}

		const from = branch ? await branchedFrom(top, branch) : undefined;
		const candidates = from ? [from.replace(/^origin\//, "")] : names;
		let best: { name: string; ref: string; mergeBase: string; ahead: number } | undefined;
		for (const name of candidates) {
			const found = await closest(top, [`origin/${name}`, name]);
			if (found && (!best || found.ahead < best.ahead)) best = { name, ...found };
		}
		if (!best) return undefined;
		return { top, branch, base: best.name, baseRef: best.ref, mergeBase: best.mergeBase, canPr: branch !== undefined };
	}

	async function countLines(file: string): Promise<number> {
		try {
			if (fs.statSync(file).size > MAX_COUNTED_BYTES) return 0;
			const body = fs.readFileSync(file);
			if (body.subarray(0, 8000).includes(0)) return 0;
			const text = body.toString("utf8");
			return text.length === 0 ? 0 : text.split("\n").length - (text.endsWith("\n") ? 1 : 0);
		} catch {
			return 0;
		}
	}

	async function openPr(repo: Repo): Promise<{ number: number; url: string } | undefined> {
		if (!repo.canPr || !repo.branch) return undefined;
		const res = await pi.exec("gh", ["pr", "view", repo.branch, "--json", "number,url,state"], { cwd: repo.top, timeout: 8000 });
		if (res.code !== 0) return undefined;
		try {
			const pr = JSON.parse(res.stdout) as { number: number; url: string; state: string };
			return pr.state === "OPEN" ? { number: pr.number, url: pr.url } : undefined;
		} catch {
			return undefined;
		}
	}

	async function buildCard(repo: Repo): Promise<Card> {
		const [numstat, newFiles, commits, porcelain, pr, sessionName] = await Promise.all([
			git(repo.top, ["diff", "--no-ext-diff", "--numstat", repo.mergeBase]),
			untracked(repo.top),
			git(repo.top, ["rev-list", "--count", `${repo.mergeBase}..HEAD`]),
			git(repo.top, ["status", "--porcelain"]),
			openPr(repo),
			Promise.resolve(pi.getSessionName()),
		]);
		const files: FileStat[] = [];
		for (const line of (numstat ?? "").split("\n")) {
			const [added, deleted, ...rest] = line.split("\t");
			if (rest.length === 0) continue;
			files.push({ path: rest.join("\t"), added: Number(added) || 0, deleted: Number(deleted) || 0 });
		}
		for (const file of newFiles) files.push({ path: file, added: await countLines(path.join(repo.top, file)), deleted: 0 });
		const commitCount = Number(commits?.trim()) || 0;
		const lastSubject = commitCount > 0 ? (await git(repo.top, ["log", "-1", "--format=%s"]))?.trim() : undefined;
		return {
			title: sessionName?.trim() || lastSubject || repo.branch || "Uncommitted changes",
			branch: repo.branch ?? "HEAD",
			base: repo.base,
			canPr: repo.canPr,
			files,
			added: files.reduce((sum, f) => sum + f.added, 0),
			deleted: files.reduce((sum, f) => sum + f.deleted, 0),
			commits: commitCount,
			dirty: Boolean(porcelain?.trim()),
			pr,
		};
	}

	/** Docks the card above the prompt; false when there is no repository or nothing changed against the base. */
	async function showCard(ctx: ExtensionContext): Promise<boolean> {
		const repo = await inspect(ctx.cwd);
		if (!repo) return false;
		const card = await buildCard(repo);
		if (card.files.length === 0) return false;
		const act = (action: Action, path?: string) => {
			if (liveCtx) void run(action, liveCtx, path);
		};
		ctx.ui.setWidget(
			WIDGET_KEY,
			(tui, theme) => {
				const fold: Fold = {
					get collapsed() {
						return collapsed;
					},
					set(next) {
						collapsed = next;
						tui.requestRender();
					},
				};
				return new GitCardView(card, theme, fold, act);
			},
			{ placement: "aboveEditor" },
		);
		ctx.ui.setWidget(GAP_KEY, () => new DockGap(), { placement: "aboveEditor" });
		return true;
	}

	function hideCard(ctx: ExtensionContext): void {
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		ctx.ui.setWidget(GAP_KEY, undefined);
	}

	/** The diff against the base in the annotation view, opened on `path` when given. */
	async function viewDiff(ctx: ExtensionContext, path?: string): Promise<void> {
		const repo = await inspect(ctx.cwd);
		if (!repo) return ctx.ui.notify("Not in a git repository with a base branch", "warning");
		let diff = (await git(repo.top, ["diff", "--no-ext-diff", "--no-color", repo.mergeBase])) ?? "";
		for (const file of await untracked(repo.top)) {
			const res = await pi.exec("git", ["diff", "--no-index", "--no-color", "--", "/dev/null", file], { cwd: repo.top, timeout: 15_000 });
			if (res.code === 1) diff += res.stdout;
		}
		if (!diff.trim()) return ctx.ui.notify(`No changes against ${repo.baseRef}`, "info");
		if (ctx.mode !== "tui") return ctx.ui.notify("The diff view needs the interactive TUI", "warning");
		if (path) diff = startAt(diff, path);
		await ctx.annotations.open({ source: { kind: "diff", diff, label: `${repo.branch ?? "HEAD"} vs ${repo.baseRef}` } });
	}

	async function pullRequest(ctx: ExtensionContext): Promise<void> {
		const repo = await inspect(ctx.cwd);
		if (!repo) return ctx.ui.notify("Not in a git repository with a base branch", "warning");
		if (!repo.canPr || !repo.branch) {
			return ctx.ui.notify(`On ${repo.branch ?? "a detached HEAD"}: switch to a feature branch to open a pull request`, "warning");
		}
		const existing = await openPr(repo);
		if (existing) {
			await pi.exec("open", [existing.url], { cwd: repo.top, timeout: 5000 });
			return;
		}
		const prompt = prPrompt({ ...repo, branch: repo.branch });
		if (ctx.isIdle()) pi.sendUserMessage(prompt);
		else pi.sendUserMessage(prompt, { deliverAs: "followUp" });
	}

	async function run(action: Action, ctx: ExtensionContext, path?: string): Promise<void> {
		try {
			await (action === "diff" ? viewDiff(ctx, path) : pullRequest(ctx));
		} catch (err) {
			ctx.ui.notify(`git-card: ${err instanceof Error ? err.message : String(err)}`, "error");
		}
	}

	pi.on("session_start", (_event, ctx) => {
		liveCtx = ctx;
		if (ctx.hasUI) hideCard(ctx);
	});

	pi.on("agent_start", (_event, ctx) => {
		if (ctx.agent.kind !== "main" || !ctx.hasUI) return;
		liveCtx = ctx;
		hideCard(ctx);
		before = fingerprint(ctx.cwd).catch(() => undefined);
	});

	pi.on("agent_end", (_event, ctx) => {
		if (ctx.agent.kind !== "main" || !ctx.hasUI) return;
		liveCtx = ctx;
		const start = before;
		before = undefined;
		if (!start) return;
		// Detached so git and gh never hold up the end of the turn; every failure stays inside.
		void (async () => {
			try {
				const [was, now] = [await start, await fingerprint(ctx.cwd)];
				if (was && now && was !== now) await showCard(ctx);
			} catch (err) {
				pi.logger.warn("git-card: card failed", err);
			}
		})();
	});

	pi.registerCommand("git-card", {
		description:
			"Git card for this branch; `/git-card diff [file]` annotates the diff against the base, `/git-card pr` opens a pull request",
		handler: async (args, ctx) => {
			liveCtx = ctx;
			const [sub = "", ...rest] = args.trim().split(/\s+/);
			if (sub === "diff") return run("diff", ctx, args.trim().slice(sub.length).trim() || undefined);
			if (sub === "pr" && rest.length === 0) return run("pr", ctx);
			if (sub) return ctx.ui.notify("Usage: /git-card [diff [file]|pr]", "warning");
			if (!(await showCard(ctx))) ctx.ui.notify("No changes against the base branch", "info");
		},
	});
}
