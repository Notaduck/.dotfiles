// The ideas store: one folder per idea under ~/ideas (or $IDEAS_DIR), a git repo.
//
//   <root>/
//     inbox.md                          one-line ideas, `- [YYYY-MM-DD] text`
//     index.json                        derived listing for the Tern sidebar (gitignored, rewritten on every write)
//     YYYY-MM-DD-<slug>/
//       idea.md                         frontmatter + your own text
//       context.md                      the session capsule: goal, decisions, evidence, open questions, next steps
//       log.md                          append-only history
//       artifacts/                      copied files (plans, reports)
//
// Every write goes through this module (the omp extension imports it, the Tern sidebar runs cli.ts), so the format
// lives in one place. Runs under Bun (omp) and Node >= 23.6 (type stripping): types only, no enums.
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";

export const STATUSES = ["seed", "parked", "shaping", "ready", "promoted", "dropped"] as const;
export type IdeaStatus = (typeof STATUSES)[number];

export interface IdeaMeta {
	id: string;
	title: string;
	status: IdeaStatus;
	tags: string[];
	project: string | null;
	jira: string | null;
	repos: Record<string, string>;
	sessions: string[];
	created: string;
	updated: string;
}

export interface Idea extends IdeaMeta {
	dir: string;
	path: string;
	body: string;
	context: string;
	log: string;
	artifacts: string[];
}

export interface IndexEntry extends IdeaMeta {
	dir: string;
	summary: string;
	artifacts: string[];
}

export interface InboxItem {
	line: number;
	date: string | null;
	text: string;
}

export interface IdeasIndex {
	version: 1;
	rev: number;
	generated: string;
	root: string;
	ideas: IndexEntry[];
	inbox: InboxItem[];
}

export interface CreateInput {
	title: string;
	status?: IdeaStatus;
	tags?: string[];
	project?: string | null;
	jira?: string | null;
	repos?: Record<string, string>;
	sessions?: string[];
	body?: string;
	context?: string;
	artifacts?: string[];
	log?: string;
}

export interface UpdateInput {
	title?: string;
	status?: IdeaStatus;
	tags?: string[];
	project?: string | null;
	jira?: string | null;
	repos?: Record<string, string>;
	sessions?: string[];
	body?: string;
	context?: string;
	artifacts?: string[];
	log?: string;
}

export interface WriteResult {
	idea: Idea;
	skippedArtifacts: string[];
}

export class IdeasError extends Error {}

const META_KEYS: (keyof IdeaMeta)[] = ["id", "title", "status", "tags", "project", "jira", "repos", "sessions", "created", "updated"];
const README = `# Ideas

Parked plans, loose ideas and scratchpads, captured from omp sessions.

- \`/idea save\`, \`/idea note\`, \`/idea open\` in omp; the Ideas sidebar in Tern (ctrl+b shift+i).
- One folder per idea: \`idea.md\` (metadata + text), \`context.md\` (session capsule), \`log.md\`, \`artifacts/\`.
- File and line claims in a capsule are pinned to the commits in \`repos:\`; re-check them before acting.
`;

export function root(): string {
	return resolve(process.env.IDEAS_DIR ?? join(homedir(), "ideas"));
}

export function today(): string {
	const d = new Date();
	const pad = (n: number) => String(n).padStart(2, "0");
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function isStatus(value: string): value is IdeaStatus {
	return (STATUSES as readonly string[]).includes(value);
}

export function slugify(title: string): string {
	const slug = title
		.normalize("NFKD")
		.replace(/[\u0300-\u036f]/g, "")
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 48)
		.replace(/-+$/g, "");
	return slug || "idea";
}

// Frontmatter ---------------------------------------------------------------------------------------------------
// A fixed schema, so a small YAML subset: `key: scalar`, `key: [a, b]`, and one-level maps (`key:` + `  sub: v`).
// Strings that YAML could misread are written as JSON strings, which YAML reads as double-quoted scalars.

function scalar(value: string): string {
	return value === "" || /[:#\[\]{},&*!|>'"%@`]|^\s|\s$|^(null|true|false|~|-?\d[\d.]*)$/i.test(value)
		? JSON.stringify(value)
		: value;
}

function unscalar(raw: string): string | null {
	const v = raw.trim();
	if (v === "" || v === "null" || v === "~") return null;
	if (v.startsWith('"')) return JSON.parse(v) as string;
	if (v.startsWith("'") && v.endsWith("'")) return v.slice(1, -1).replace(/''/g, "'");
	return v;
}

function splitList(inner: string): string[] {
	const out: string[] = [];
	let cur = "";
	let quoted = false;
	for (let i = 0; i < inner.length; i++) {
		const c = inner[i];
		if (c === '"' && inner[i - 1] !== "\\") quoted = !quoted;
		if (c === "," && !quoted) {
			out.push(cur);
			cur = "";
		} else {
			cur += c;
		}
	}
	if (cur.trim() !== "") out.push(cur);
	return out.map((s) => unscalar(s)).filter((s): s is string => s !== null);
}

export function serializeFrontmatter(meta: IdeaMeta): string {
	const lines = ["---"];
	for (const key of META_KEYS) {
		const value = meta[key];
		if (Array.isArray(value)) {
			lines.push(`${key}: [${value.map(scalar).join(", ")}]`);
		} else if (value && typeof value === "object") {
			const entries = Object.entries(value);
			if (entries.length === 0) {
				lines.push(`${key}: {}`);
			} else {
				lines.push(`${key}:`);
				for (const [k, v] of entries) lines.push(`  ${scalar(k)}: ${scalar(v)}`);
			}
		} else {
			lines.push(`${key}: ${value === null ? "null" : scalar(String(value))}`);
		}
	}
	lines.push("---", "");
	return lines.join("\n");
}

export function parseFrontmatter(text: string): { meta: Record<string, unknown>; body: string } {
	const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text);
	if (!match) return { meta: {}, body: text };
	const meta: Record<string, unknown> = {};
	let mapKey: string | null = null;
	for (const line of match[1].split(/\r?\n/)) {
		if (line.trim() === "" || line.trimStart().startsWith("#")) continue;
		const nested = /^\s+("[^"]*"|[^:]+):\s*(.*)$/.exec(line);
		if (nested && mapKey && /^\s/.test(line)) {
			const k = unscalar(nested[1]) ?? "";
			(meta[mapKey] as Record<string, string>)[k] = unscalar(nested[2]) ?? "";
			continue;
		}
		const top = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
		if (!top) continue;
		const [, key, rawValue] = top;
		const value = rawValue.trim();
		mapKey = null;
		if (value === "") {
			meta[key] = {};
			mapKey = key;
		} else if (value === "{}") {
			meta[key] = {};
		} else if (value.startsWith("[") && value.endsWith("]")) {
			meta[key] = splitList(value.slice(1, -1));
		} else {
			meta[key] = unscalar(value);
		}
	}
	return { meta, body: text.slice(match[0].length) };
}

function toMeta(raw: Record<string, unknown>, dir: string): IdeaMeta {
	const str = (v: unknown): string | null => (typeof v === "string" && v !== "" ? v : null);
	const list = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
	const map = (v: unknown): Record<string, string> =>
		v && typeof v === "object" && !Array.isArray(v)
			? Object.fromEntries(Object.entries(v as Record<string, unknown>).filter((e): e is [string, string] => typeof e[1] === "string"))
			: {};
	const status = str(raw.status);
	const created = str(raw.created) ?? dir.slice(0, 10);
	return {
		id: str(raw.id) ?? dir.replace(/^\d{4}-\d{2}-\d{2}-/, ""),
		title: str(raw.title) ?? dir,
		status: status && isStatus(status) ? status : "seed",
		tags: list(raw.tags),
		project: str(raw.project),
		jira: str(raw.jira),
		repos: map(raw.repos),
		sessions: list(raw.sessions),
		created,
		updated: str(raw.updated) ?? created,
	};
}

// Reading -------------------------------------------------------------------------------------------------------

function readText(path: string): string {
	return existsSync(path) ? readFileSync(path, "utf8") : "";
}

function ideaDirs(): string[] {
	const base = root();
	if (!existsSync(base)) return [];
	return readdirSync(base)
		.filter((name) => !name.startsWith(".") && existsSync(join(base, name, "idea.md")))
		.sort();
}

function listArtifacts(dir: string): string[] {
	const path = join(root(), dir, "artifacts");
	if (!existsSync(path)) return [];
	return readdirSync(path)
		.filter((name) => !name.startsWith(".") && statSync(join(path, name)).isFile())
		.sort();
}

export function loadIdea(dir: string): Idea {
	const path = join(root(), dir);
	const { meta, body } = parseFrontmatter(readText(join(path, "idea.md")));
	return {
		...toMeta(meta, dir),
		dir,
		path,
		body: body.trim(),
		context: readText(join(path, "context.md")).trim(),
		log: readText(join(path, "log.md")).trim(),
		artifacts: listArtifacts(dir),
	};
}

export function listIdeas(): Idea[] {
	return ideaDirs()
		.map(loadIdea)
		.sort((a, b) => b.updated.localeCompare(a.updated) || b.created.localeCompare(a.created));
}

/** Finds an idea by id, folder name, Jira key, or a unique id/folder prefix. */
export function findIdea(ref: string): Idea {
	const want = ref.trim().toLowerCase();
	if (!want) throw new IdeasError("No idea id given");
	const ideas = listIdeas();
	const exact = ideas.find((i) => i.id.toLowerCase() === want || i.dir.toLowerCase() === want || i.jira?.toLowerCase() === want);
	if (exact) return exact;
	const prefixed = ideas.filter((i) => i.id.toLowerCase().startsWith(want) || i.dir.toLowerCase().startsWith(want));
	if (prefixed.length === 1) return prefixed[0];
	if (prefixed.length > 1) throw new IdeasError(`"${ref}" matches ${prefixed.length} ideas: ${prefixed.map((i) => i.id).join(", ")}`);
	throw new IdeasError(`No idea matches "${ref}"`);
}

export function searchIdeas(query: string): Idea[] {
	const words = query.toLowerCase().split(/\s+/).filter(Boolean);
	const ideas = listIdeas();
	if (words.length === 0) return ideas;
	return ideas.filter((i) => {
		const hay = [i.id, i.title, i.status, i.jira ?? "", i.project ?? "", ...i.tags, i.body, i.context].join("\n").toLowerCase();
		return words.every((w) => hay.includes(w));
	});
}

export function readInbox(): InboxItem[] {
	const lines = readText(join(root(), "inbox.md")).split(/\r?\n/);
	const items: InboxItem[] = [];
	lines.forEach((line, i) => {
		const m = /^\s*[-*]\s+(?:\[(\d{4}-\d{2}-\d{2})\]\s+)?(.+)$/.exec(line);
		if (m) items.push({ line: i + 1, date: m[1] ?? null, text: m[2].trim() });
	});
	return items;
}

function summaryOf(body: string): string {
	const para = body
		.split(/\n\s*\n/)
		.map((p) => p.trim())
		.find((p) => p !== "" && !p.startsWith("#"));
	const flat = (para ?? "").replace(/\s+/g, " ");
	return flat.length > 200 ? `${flat.slice(0, 199)}…` : flat;
}

// Writing -------------------------------------------------------------------------------------------------------

function git(args: string[]): { ok: boolean; out: string } {
	const r = spawnSync("git", args, { cwd: root(), encoding: "utf8" });
	return { ok: r.status === 0, out: `${r.stdout ?? ""}${r.stderr ?? ""}`.trim() };
}

function commit(message: string): void {
	git(["add", "-A"]);
	const staged = git(["diff", "--cached", "--quiet"]);
	if (!staged.ok) git(["commit", "-q", "-m", message]);
}

export function reindex(): IdeasIndex {
	const index: IdeasIndex = {
		version: 1,
		rev: Date.now(),
		generated: new Date().toISOString(),
		root: root(),
		ideas: listIdeas().map((i) => ({
			id: i.id,
			title: i.title,
			status: i.status,
			tags: i.tags,
			project: i.project,
			jira: i.jira,
			repos: i.repos,
			sessions: i.sessions,
			created: i.created,
			updated: i.updated,
			dir: i.dir,
			summary: summaryOf(i.body),
			artifacts: i.artifacts,
		})),
		inbox: readInbox(),
	};
	writeFileSync(join(root(), "index.json"), `${JSON.stringify(index, null, 2)}\n`);
	return index;
}

export function ensureStore(): string {
	const base = root();
	mkdirSync(base, { recursive: true });
	const fresh = !existsSync(join(base, ".git"));
	if (fresh) git(["init", "-q", "-b", "main"]);
	if (!existsSync(join(base, "README.md"))) writeFileSync(join(base, "README.md"), README);
	if (!existsSync(join(base, "inbox.md"))) writeFileSync(join(base, "inbox.md"), "# Inbox\n\n");
	if (!existsSync(join(base, ".gitignore"))) writeFileSync(join(base, ".gitignore"), "index.json\n.DS_Store\n");
	if (!existsSync(join(base, "index.json"))) reindex();
	if (fresh) commit("Initialize ideas store");
	return base;
}

function writeIdeaFile(idea: IdeaMeta & { path: string }, body: string): void {
	writeFileSync(join(idea.path, "idea.md"), `${serializeFrontmatter(idea)}${body.trim()}\n`);
}

function copyArtifacts(dir: string, paths: string[]): string[] {
	const skipped: string[] = [];
	const target = join(root(), dir, "artifacts");
	for (const raw of paths) {
		const src = resolve(raw.replace(/^~(?=\/|$)/, homedir()));
		if (!existsSync(src) || !statSync(src).isFile()) {
			skipped.push(raw);
			continue;
		}
		mkdirSync(target, { recursive: true });
		copyFileSync(src, join(target, basename(src)));
	}
	return skipped;
}

function appendLog(path: string, entry: string): void {
	const file = join(path, "log.md");
	const head = existsSync(file) ? readFileSync(file, "utf8").replace(/\s*$/, "\n") : "# Log\n\n";
	writeFileSync(file, `${head}- ${today()} ${entry.replace(/\s+/g, " ").trim()}\n`);
}

function uniqueId(slug: string): string {
	const taken = new Set(listIdeas().map((i) => i.id));
	if (!taken.has(slug)) return slug;
	for (let n = 2; ; n++) if (!taken.has(`${slug}-${n}`)) return `${slug}-${n}`;
}

export function createIdea(input: CreateInput): WriteResult {
	ensureStore();
	const title = input.title.trim();
	if (!title) throw new IdeasError("An idea needs a title");
	const id = uniqueId(slugify(title));
	const created = today();
	let dir = `${created}-${id}`;
	for (let n = 2; existsSync(join(root(), dir)); n++) dir = `${created}-${id}-${n}`;
	const path = join(root(), dir);
	mkdirSync(path, { recursive: true });
	const meta: IdeaMeta = {
		id,
		title,
		status: input.status ?? "seed",
		tags: [...new Set(input.tags ?? [])],
		project: input.project ?? null,
		jira: input.jira ?? null,
		repos: input.repos ?? {},
		sessions: [...new Set(input.sessions ?? [])],
		created,
		updated: created,
	};
	writeIdeaFile({ ...meta, path }, `# ${title}\n\n${(input.body ?? "").trim()}`);
	if (input.context?.trim()) writeFileSync(join(path, "context.md"), `${input.context.trim()}\n`);
	const skippedArtifacts = copyArtifacts(dir, input.artifacts ?? []);
	appendLog(path, input.log ?? `Created${meta.sessions.length ? ` from session ${meta.sessions.at(-1)}` : ""}`);
	reindex();
	commit(`Add idea ${id}`);
	return { idea: loadIdea(dir), skippedArtifacts };
}

export function updateIdea(ref: string, patch: UpdateInput): WriteResult {
	ensureStore();
	const current = findIdea(ref);
	const changed: string[] = [];
	const meta: IdeaMeta = {
		id: current.id,
		title: patch.title?.trim() || current.title,
		status: patch.status ?? current.status,
		tags: patch.tags ? [...new Set(patch.tags)] : current.tags,
		project: patch.project === undefined ? current.project : patch.project,
		jira: patch.jira === undefined ? current.jira : patch.jira,
		repos: { ...current.repos, ...(patch.repos ?? {}) },
		sessions: [...new Set([...current.sessions, ...(patch.sessions ?? [])])],
		created: current.created,
		updated: today(),
	};
	if (meta.title !== current.title) changed.push("title");
	if (meta.status !== current.status) changed.push(`status ${current.status} → ${meta.status}`);
	if (meta.jira !== current.jira) changed.push(`jira ${meta.jira ?? "removed"}`);
	if (patch.tags) changed.push("tags");
	if (patch.repos && Object.keys(patch.repos).length) changed.push("repos");
	if (meta.sessions.length > current.sessions.length) changed.push(`session ${meta.sessions.at(-1)}`);
	const body = patch.body === undefined ? current.body : `# ${meta.title}\n\n${patch.body.trim()}`;
	writeIdeaFile({ ...meta, path: current.path }, body);
	if (patch.context !== undefined) {
		writeFileSync(join(current.path, "context.md"), `${patch.context.trim()}\n`);
		changed.push("context");
	}
	if (patch.body !== undefined) changed.push("text");
	const skippedArtifacts = copyArtifacts(current.dir, patch.artifacts ?? []);
	if ((patch.artifacts?.length ?? 0) > skippedArtifacts.length) changed.push("artifacts");
	appendLog(current.path, patch.log ?? `Updated: ${changed.join(", ") || "no changes"}`);
	reindex();
	commit(`Update idea ${current.id}${changed.length ? `: ${changed.join(", ")}` : ""}`);
	return { idea: loadIdea(current.dir), skippedArtifacts };
}

export function setStatus(ref: string, status: IdeaStatus): Idea {
	return updateIdea(ref, { status }).idea;
}

export function addInbox(text: string): InboxItem {
	ensureStore();
	const line = text.replace(/\s+/g, " ").trim();
	if (!line) throw new IdeasError("Nothing to note");
	const file = join(root(), "inbox.md");
	const head = readText(file).replace(/\s*$/, "\n");
	const lastLine = head.trimEnd().split("\n").at(-1) ?? "";
	writeFileSync(file, `${head}${/^\s*[-*]\s/.test(lastLine) ? "" : "\n"}- [${today()}] ${line}\n`);
	reindex();
	commit(`Note: ${line.slice(0, 60)}`);
	const items = readInbox();
	return items[items.length - 1];
}

// Rendering -----------------------------------------------------------------------------------------------------

/** What `/idea open` puts into a chat: the idea, how old its evidence is, and where its files are. */
export function renderForContext(idea: Idea): string {
	const repos = Object.entries(idea.repos).map(([name, sha]) => `${name} ${sha}`);
	const lines = [
		`# Idea: ${idea.title}`,
		"",
		`id \`${idea.id}\` · status ${idea.status}${idea.jira ? ` · Jira ${idea.jira}` : ""}${idea.tags.length ? ` · tags ${idea.tags.join(", ")}` : ""}`,
		`Captured ${idea.created}, updated ${idea.updated}${repos.length ? `, against ${repos.join(", ")}` : ""}.`,
		"File, line and behaviour claims below are pinned to those commits: re-check them against the current code before acting on them.",
		`Folder: ${idea.path}${idea.sessions.length ? ` · sessions: ${idea.sessions.join(", ")} (omp --resume <id>)` : ""}`,
	];
	if (idea.artifacts.length) {
		lines.push("Artifacts:", ...idea.artifacts.map((a) => `- ${join(idea.path, "artifacts", a)}`));
	}
	lines.push("", "## idea.md", "", idea.body || "(empty)");
	if (idea.context) lines.push("", "## context.md", "", idea.context);
	return lines.join("\n");
}
