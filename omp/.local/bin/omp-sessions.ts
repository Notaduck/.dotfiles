// omp-sessions: find omp sessions by Jira key, idea, title words or id, and resume them.
// Run with Node >= 23.6 (type stripping, node:sqlite). Read-only: never writes omp's files or databases.
//
//   omp-sessions list [--json] [--days N] [--limit N] [query...]   sessions, newest first
//   omp-sessions find <ident> [--json]                              best matches for a Jira key, idea id, id prefix or words
//   omp-sessions resume <ident>                                     cd to the best match's cwd and exec `omp --resume <id>`
//
// Identifiers per session:
//   keys      Jira keys in its title and in its cwd's folder name (worktrees are named after the key)
//   mentions  Jira keys in prompts typed into it (history.db), e.g. `/implement PROJ-123`
//   ideas     ideas in ~/ideas that list the session
import { spawnSync } from "node:child_process";
import { closeSync, existsSync, openSync, readdirSync, readFileSync, readSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { DatabaseSync } from "node:sqlite";

export interface SessionInfo {
	id: string;
	title: string;
	cwd: string;
	created: string;
	modified: string;
	file: string;
	keys: string[];
	mentions: string[];
	ideas: string[];
	recap: string | null;
}

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".omp", "agent");
const SESSIONS_DIR = join(AGENT_DIR, "sessions");
const HISTORY_DB = join(AGENT_DIR, "history.db");
const IDEAS_INDEX = join(process.env.IDEAS_DIR ?? join(homedir(), "ideas"), "index.json");
const HEADER_BYTES = 16 * 1024;
const KEY_RE = /\b([A-Z][A-Z0-9]{1,9})-(\d{1,6})\b/g;
// Hyphenated tokens that look like Jira keys but are not.
const NOT_PROJECTS: Record<string, true> = Object.fromEntries(
	["UTF", "SHA", "ISO", "AES", "RFC", "CVE", "GHSA", "HTTP", "TLS", "SSL", "MD", "ES", "IPV", "TCP", "UDP", "ECMA", "WCAG"].map((p) => [p, true]),
);

function jiraKeys(text: string): string[] {
	const out = new Set<string>();
	for (const m of text.matchAll(KEY_RE)) if (!NOT_PROJECTS[m[1]]) out.add(`${m[1]}-${m[2]}`);
	return [...out];
}

function readHeader(file: string): { id?: string; title?: string; cwd?: string; timestamp?: string } {
	const fd = openSync(file, "r");
	try {
		const buf = Buffer.alloc(HEADER_BYTES);
		const n = readSync(fd, buf, 0, HEADER_BYTES, 0);
		const header: { id?: string; title?: string; cwd?: string; timestamp?: string } = {};
		for (const line of buf.subarray(0, n).toString("utf8").split("\n").slice(0, 8)) {
			try {
				const entry = JSON.parse(line) as Record<string, unknown>;
				if (entry.type === "title" && typeof entry.title === "string") header.title = entry.title;
				if (entry.type === "session") {
					if (typeof entry.id === "string") header.id = entry.id;
					if (typeof entry.cwd === "string") header.cwd = entry.cwd;
					if (typeof entry.timestamp === "string") header.timestamp = entry.timestamp;
				}
			} catch {
				// a partial last line, or a non-JSON line
			}
		}
		return header;
	} finally {
		closeSync(fd);
	}
}

function sessionFiles(): string[] {
	if (!existsSync(SESSIONS_DIR)) return [];
	const files: string[] = [];
	for (const project of readdirSync(SESSIONS_DIR)) {
		const dir = join(SESSIONS_DIR, project);
		if (!statSync(dir).isDirectory()) continue;
		for (const name of readdirSync(dir)) if (name.endsWith(".jsonl")) files.push(join(dir, name));
	}
	return files;
}

function ideasBySession(): Map<string, string[]> {
	const map = new Map<string, string[]>();
	if (!existsSync(IDEAS_INDEX)) return map;
	try {
		const index = JSON.parse(readFileSync(IDEAS_INDEX, "utf8")) as { ideas?: { id: string; jira: string | null; sessions?: string[] }[] };
		for (const idea of index.ideas ?? []) {
			for (const s of idea.sessions ?? []) map.set(s, [...(map.get(s) ?? []), idea.id]);
		}
	} catch {
		// index being rewritten; ideas are optional
	}
	return map;
}

export function loadSessions(days: number): SessionInfo[] {
	const cutoff = Date.now() - days * 86_400_000;
	const db = existsSync(HISTORY_DB) ? new DatabaseSync(HISTORY_DB, { readOnly: true }) : null;
	const titles = new Map<string, string>();
	const prompts = new Map<string, string[]>();
	const recaps = new Map<string, string>();
	if (db) {
		for (const row of db.prepare("SELECT session_id, title FROM session_titles").all() as { session_id: string; title: string }[]) {
			titles.set(row.session_id, row.title);
		}
		for (const row of db.prepare("SELECT session_id, prompt FROM history WHERE session_id IS NOT NULL").all() as { session_id: string; prompt: string }[]) {
			prompts.set(row.session_id, [...(prompts.get(row.session_id) ?? []), row.prompt]);
		}
		for (const row of db.prepare("SELECT session_id, recap FROM session_recaps ORDER BY created_at").all() as { session_id: string; recap: string }[]) {
			recaps.set(row.session_id, row.recap);
		}
		db.close();
	}
	const ideas = ideasBySession();
	const sessions: SessionInfo[] = [];
	for (const file of sessionFiles()) {
		const mtime = statSync(file).mtimeMs;
		if (mtime < cutoff) continue;
		const header = readHeader(file);
		const id = header.id ?? /_([0-9a-f-]{36})\.jsonl$/.exec(file)?.[1];
		if (!id) continue;
		const title = titles.get(id) ?? header.title ?? "";
		const cwd = header.cwd ?? "";
		const keys = [...new Set([...jiraKeys(title), ...jiraKeys(basename(cwd))])];
		sessions.push({
			id,
			title,
			cwd,
			created: header.timestamp ?? new Date(mtime).toISOString(),
			modified: new Date(mtime).toISOString(),
			file,
			keys,
			mentions: jiraKeys((prompts.get(id) ?? []).join("\n")).filter((k) => !keys.includes(k)),
			ideas: ideas.get(id) ?? [],
			recap: recaps.get(id) ?? null,
		});
	}
	return sessions.sort((a, b) => b.modified.localeCompare(a.modified));
}

/** Ranks sessions for an identifier: exact id/prefix, Jira key in title or folder, idea, key in prompts, then words. */
export function findSessions(sessions: SessionInfo[], ident: string): SessionInfo[] {
	const raw = ident.trim();
	const upper = raw.toUpperCase();
	const lower = raw.toLowerCase();
	const score = (s: SessionInfo): number => {
		if (s.id === raw || (raw.length >= 6 && s.id.startsWith(raw))) return 100;
		if (s.keys.includes(upper)) return 80;
		if (s.ideas.some((i) => i === lower || i.startsWith(lower))) return 70;
		if (s.mentions.includes(upper)) return 50;
		const hay = `${s.title}\n${s.cwd}\n${s.recap ?? ""}`.toLowerCase();
		const words = lower.split(/\s+/).filter(Boolean);
		return words.length && words.every((w) => hay.includes(w)) ? 20 : 0;
	};
	return sessions
		.map((s) => ({ s, n: score(s) }))
		.filter((x) => x.n > 0)
		.sort((a, b) => b.n - a.n || b.s.modified.localeCompare(a.s.modified))
		.map((x) => x.s);
}

function flag(args: string[], name: string, fallback: number): number {
	const i = args.indexOf(name);
	if (i === -1) return fallback;
	const value = Number(args.splice(i, 2)[1]);
	return Number.isFinite(value) && value > 0 ? value : fallback;
}

function line(s: SessionInfo): string {
	const tags = [...s.keys, ...s.ideas.map((i) => `idea:${i}`)].join(" ");
	return `${s.id.slice(0, 13)}  ${s.modified.slice(0, 10)}  ${tags ? `${tags}  ` : ""}${s.title}  (${s.cwd.replace(homedir(), "~")})`;
}

function main(argv: string[]): number {
	const args = [...argv];
	const json = args.includes("--json");
	const rest = args.filter((a) => a !== "--json");
	const [command, ...tail] = rest;
	const days = flag(tail, "--days", 365);
	const limit = flag(tail, "--limit", 500);
	switch (command) {
		case "list": {
			const all = loadSessions(days);
			const found = (tail.length ? findSessions(all, tail.join(" ")) : all).slice(0, limit);
			console.log(json ? JSON.stringify(found, null, 2) : found.map(line).join("\n"));
			return 0;
		}
		case "find": {
			if (!tail.length) break;
			const found = findSessions(loadSessions(days), tail.join(" ")).slice(0, json ? limit : 10);
			if (!found.length) {
				console.error(`No session matches "${tail.join(" ")}"`);
				return 1;
			}
			console.log(json ? JSON.stringify(found, null, 2) : found.map(line).join("\n"));
			return 0;
		}
		case "resume": {
			if (!tail.length) break;
			const [best] = findSessions(loadSessions(days), tail.join(" "));
			if (!best) {
				console.error(`No session matches "${tail.join(" ")}"`);
				return 1;
			}
			console.error(`Resuming ${line(best)}`);
			const cwd = existsSync(best.cwd) ? best.cwd : homedir();
			return spawnSync("omp", ["--resume", best.id], { cwd, stdio: "inherit" }).status ?? 1;
		}
	}
	console.error("usage: omp-sessions list [--json] [--days N] [--limit N] [query] | find <ident> [--json] | resume <ident>");
	return 2;
}

process.exitCode = main(process.argv.slice(2));
