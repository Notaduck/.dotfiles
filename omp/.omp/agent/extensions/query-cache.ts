// Caches read-only AWS CLI and MCP query results across sessions and gives the agent a
// `query_cache` tool to look them up later instead of re-querying.
//
// What gets cached (successful results only, latest result per identical query):
// - bash commands whose every `aws` invocation is a read (describe-*, list-*, get-*, s3 ls, logs tail, ...),
//   minus credential/secret reads (secretsmanager get-secret-value, ssm --with-decryption, sts, ecr login, ...)
// - MCP calls made through `xd://` devices whose server marks the tool read-only (`readOnlyHint`); tools without
//   the annotation (writes, and servers that annotate nothing) are never cached
//
// The cache never answers a query on its own: the agent searches it with `query_cache` when live data is not needed.
//
// Store: ~/.cache/omp/query-cache.sqlite (or $XDG_CACHE_HOME/omp), mode 0600, entries pruned after 30 days.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { Database } from "bun:sqlite";
import { createHash } from "node:crypto";
import { chmodSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const RETENTION_DAYS = 30;
const MAX_ENTRY_BYTES = 2 * 1024 * 1024;
const PAGE_CHARS = 40_000;

const AWS_READ_OP = /^(describe|list|get|batch-get|scan|query|search|lookup|filter|head|select|tail|ls)(-|$)/;
// Reads that return credentials or secret values: never persist them.
const AWS_SECRET_OPS: Array<[service: RegExp, op: RegExp]> = [
	[/^secretsmanager$/, /^(get-secret-value|batch-get-secret-value)$/],
	[/^sts$/, /./],
	[/^sso$/, /./],
	[/^sso-oidc$/, /./],
	[/^ecr$/, /^(get-login-password|get-authorization-token)$/],
	[/^ecr-public$/, /^(get-login-password|get-authorization-token)$/],
	[/^codeartifact$/, /^get-authorization-token$/],
	[/^cognito-identity$/, /^(get-credentials-for-identity|get-open-id-token)/],
	[/^kms$/, /^(decrypt|generate-data-key)/],
	[/^rds$/, /^generate-db-auth-token$/],
	[/^iam$/, /^get-(ssh-public-key|service-specific-credential)/],
	[/^configure$/, /./],
	[/^lightsail$/, /^(get-instance-access-details|download-default-key-pair)$/],
];
// aws global flags that take no value (everything else starting with `--` before the service takes one).
const AWS_BOOLEAN_FLAGS: Record<string, true> = {
	"--debug": true,
	"--no-verify-ssl": true,
	"--no-paginate": true,
	"--no-sign-request": true,
	"--no-cli-pager": true,
	"--cli-auto-prompt": true,
	"--no-cli-auto-prompt": true,
};

type CacheRow = {
	id: number;
	source: "aws" | "mcp";
	name: string;
	label: string;
	output: string;
	truncated: number;
	profile: string | null;
	cwd: string;
	created_at: number;
};

const DB_DIR = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "omp");
const DB_FILE = join(DB_DIR, "query-cache.sqlite");
let database: Database | undefined;

function db(): Database {
	if (database) return database;
	mkdirSync(DB_DIR, { recursive: true, mode: 0o700 });
	const fresh = !existsSync(DB_FILE);
	database = new Database(DB_FILE, { create: true });
	if (fresh) chmodSync(DB_FILE, 0o600);
	database.run("PRAGMA journal_mode = WAL");
	database.run(`CREATE TABLE IF NOT EXISTS entries (
		id INTEGER PRIMARY KEY,
		key TEXT NOT NULL UNIQUE,
		source TEXT NOT NULL,
		name TEXT NOT NULL,
		label TEXT NOT NULL,
		output TEXT NOT NULL,
		truncated INTEGER NOT NULL,
		profile TEXT,
		cwd TEXT NOT NULL,
		created_at INTEGER NOT NULL
	)`);
	database.run("CREATE INDEX IF NOT EXISTS entries_created_at ON entries(created_at)");
	database.run("DELETE FROM entries WHERE created_at < ?", [Date.now() - RETENTION_DAYS * 86_400_000]);
	return database;
}

function store(entry: Omit<CacheRow, "id" | "created_at">) {
	// The label is the full command / tool call, so it identifies the query (per AWS profile).
	const key = createHash("sha256")
		.update(`${entry.source}\0${entry.label}\0${entry.profile ?? ""}`)
		.digest("hex");
	let { output, truncated } = entry;
	if (Buffer.byteLength(output) > MAX_ENTRY_BYTES) {
		output = Buffer.from(output).subarray(0, MAX_ENTRY_BYTES).toString();
		truncated = 1;
	}
	// Replacing the row gives a re-run query a new id and timestamp, so search order stays newest-first.
	db().run(
		`INSERT OR REPLACE INTO entries (key, source, name, label, output, truncated, profile, cwd, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		[key, entry.source, entry.name, entry.label, output, truncated, entry.profile, entry.cwd, Date.now()],
	);
}

/** Full bash output, read back from the session artifact omp spills long output to when it truncates. */
function bashOutput(content: unknown, details: unknown, sessionFile: string | undefined) {
	const meta = details && typeof details === "object" && "meta" in details ? details.meta : undefined;
	const truncation = meta && typeof meta === "object" && "truncation" in meta ? meta.truncation : undefined;
	if (!truncation) return { output: textOf(content), truncated: 0 };
	const artifactId = typeof truncation === "object" && "artifactId" in truncation ? truncation.artifactId : undefined;
	const file =
		sessionFile && artifactId !== undefined
			? join(sessionFile.replace(/\.jsonl$/, ""), `${String(artifactId)}.bash.log`)
			: undefined;
	return file && existsSync(file)
		? { output: readFileSync(file, "utf8"), truncated: 0 }
		: { output: textOf(content), truncated: 1 };
}

function stableJson(value: unknown): string {
	if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
	if (value && typeof value === "object") {
		const record = value as Record<string, unknown>;
		return `{${Object.keys(record)
			.sort()
			.map(k => `${JSON.stringify(k)}:${stableJson(record[k])}`)
			.join(",")}}`;
	}
	return JSON.stringify(value) ?? "null";
}

function textOf(content: unknown): string {
	if (!Array.isArray(content)) return "";
	return content
		.map(part =>
			part && typeof part === "object" && "type" in part && part.type === "text" && "text" in part
				? String(part.text)
				: "",
		)
		.join("");
}

/** Returns `service op` for each aws invocation, or undefined when any of them is not a cacheable read. */
function awsReads(command: string): string[] | undefined {
	const reads: string[] = [];
	for (const segment of command.split(/&&|\|\||[;|\n]|\$\(|`/)) {
		const tokens = segment.trim().split(/\s+/).filter(Boolean);
		let i = 0;
		while (i < tokens.length && (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i]) || /^(time|command|exec|env)$/.test(tokens[i])))
			i++;
		if (tokens[i] !== "aws") continue;
		const positional: string[] = [];
		for (i++; i < tokens.length && positional.length < 2; i++) {
			const token = tokens[i];
			if (!token.startsWith("--")) positional.push(token);
			else if (!AWS_BOOLEAN_FLAGS[token] && !token.includes("=")) i++;
		}
		const [service, op] = positional;
		if (!service || !op || !AWS_READ_OP.test(op)) return undefined;
		if (AWS_SECRET_OPS.some(([s, o]) => s.test(service) && o.test(op))) return undefined;
		if (service === "ssm" && /--with-decryption\b/.test(segment)) return undefined;
		reads.push(`${service} ${op}`);
	}
	return reads.length ? reads : undefined;
}

function age(ms: number): string {
	const minutes = Math.round((Date.now() - ms) / 60_000);
	if (minutes < 1) return "just now";
	if (minutes < 60) return `${minutes}m ago`;
	const hours = Math.round(minutes / 60);
	return hours < 48 ? `${hours}h ago` : `${Math.round(hours / 24)}d ago`;
}

function snippet(output: string, terms: string[]): string {
	const lower = output.toLowerCase();
	const hit = terms.map(t => lower.indexOf(t)).find(i => i >= 0) ?? 0;
	const start = Math.max(0, hit - 80);
	return output.slice(start, start + 240).replace(/\s+/g, " ").trim();
}

export default function queryCache(pi: ExtensionAPI) {
	const z = pi.zod;
	pi.on("tool_result", async (event, ctx) => {
		if (event.isError) return;
		try {
			if (event.toolName === "bash") {
				const command = typeof event.input.command === "string" ? event.input.command.trim() : "";
				const reads = command && awsReads(command);
				if (!reads) return;
				const profile = process.env.AWS_PROFILE ?? null;
				store({
					source: "aws",
					name: reads.join(", "),
					label: command,
					...bashOutput(event.content, event.details, ctx.sessionManager.getSessionFile()),
					profile,
					cwd: ctx.cwd,
				});
			} else if (event.toolName === "write") {
				// An `xd://mcp__*` device call; its details carry the MCP tool, its args and the server's annotations.
				const details = event.details;
				const xdev = details && typeof details === "object" && "xdev" in details ? details.xdev : undefined;
				if (!xdev || typeof xdev !== "object" || !("tool" in xdev) || typeof xdev.tool !== "string") return;
				if (!xdev.tool.startsWith("mcp__")) return;
				if (!("readOnlyHint" in xdev) || xdev.readOnlyHint !== true) return;
				const args = stableJson("args" in xdev ? xdev.args : {});
				store({
					source: "mcp",
					name: xdev.tool,
					label: `${xdev.tool} ${args}`,
					output: textOf(event.content),
					truncated: 0,
					profile: null,
					cwd: ctx.cwd,
				});
			}
		} catch (error) {
			pi.logger.warn("query-cache: failed to store result", { error: String(error) });
		}
	});

	pi.registerTool({
		name: "query_cache",
		label: "Query Cache",
		description:
			"Look up earlier results of read-only AWS CLI commands and MCP tool calls (Jira, Confluence, ...), " +
			"cached automatically across sessions for 30 days. Search it before re-running such a query when the " +
			"answer need not be live (resource ARNs/IDs, config, account layout, issue details), and check the age " +
			"shown. Search with `query` (space-separated terms, all must match the command/tool call or its output), " +
			"then read one entry in full with `id`. Re-run the real query when freshness matters.",
		parameters: z.object({
			query: z.string().optional().describe("Terms to match, e.g. `lambda list-functions staging` or `PROJ-123`"),
			source: z.enum(["aws", "mcp"]).optional().describe("Restrict search to one source"),
			id: z.number().int().optional().describe("Entry id from a search result: returns its full output"),
			offset: z.number().int().optional().describe("With `id`: character offset to page through long output"),
			limit: z.number().int().optional().describe("Max search results (default 10)"),
		}),
		loadMode: "essential",
		approval: "read",
		async execute(_toolCallId, params) {
			if (params.id !== undefined) {
				const row = db().query("SELECT * FROM entries WHERE id = ?").get(params.id) as CacheRow | null;
				if (!row) return { content: [{ type: "text", text: `No cache entry ${params.id}.` }], isError: true };
				const offset = Math.max(0, params.offset ?? 0);
				const page = row.output.slice(offset, offset + PAGE_CHARS);
				const end = offset + page.length;
				const header = [
					`#${row.id} ${row.source} · cached ${age(row.created_at)} (${new Date(row.created_at).toISOString()})`,
					row.label,
					row.profile ? `AWS_PROFILE=${row.profile}` : "",
					row.truncated ? "Note: omp truncated this output when it was cached; it is incomplete." : "",
					end < row.output.length
						? `Showing chars ${offset}-${end} of ${row.output.length}; continue with offset ${end}.`
						: "",
				].filter(Boolean);
				return {
					content: [{ type: "text", text: `${header.join("\n")}\n\n${page}` }],
					details: { id: row.id },
				};
			}

			const terms = (params.query ?? "").toLowerCase().split(/\s+/).filter(Boolean);
			const where: string[] = [];
			const args: Array<string | number> = [];
			for (const term of terms) {
				where.push("(lower(label) LIKE ? OR lower(name) LIKE ? OR lower(output) LIKE ?)");
				const like = `%${term}%`;
				args.push(like, like, like);
			}
			if (params.source) {
				where.push("source = ?");
				args.push(params.source);
			}
			const limit = Math.min(Math.max(params.limit ?? 10, 1), 50);
			const rows = db()
				.query(
					`SELECT * FROM entries ${where.length ? `WHERE ${where.join(" AND ")}` : ""} ORDER BY created_at DESC LIMIT ?`,
				)
				.all(...args, limit) as CacheRow[];
			if (!rows.length) return { content: [{ type: "text", text: "No cached results match." }] };
			const text = rows
				.map(
					row =>
						`#${row.id} ${row.source} · ${age(row.created_at)} · ${row.output.length} chars${row.truncated ? " (incomplete)" : ""}` +
						`${row.profile ? ` · AWS_PROFILE=${row.profile}` : ""}\n  ${row.label.slice(0, 300)}\n  ${snippet(row.output, terms)}`,
				)
				.join("\n");
			return { content: [{ type: "text", text }], details: { ids: rows.map(r => r.id) } };
		},
	});
}
