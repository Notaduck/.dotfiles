// Ideas: park plans, loose ideas and scratchpads from a session in ~/ideas, and load them into a later one.
//
// /idea save [title]      summarise this session into a new idea (side request, reviewed in the editor first)
// /idea update <ref>      refresh an idea's capsule from this session
// /idea note <text>       one line into the inbox, no model call
// /idea open [ref]        put an idea into this chat as context, no model turn (picker without a ref)
// /idea list [query]      pick an idea to open
// /idea status <ref> <s>  seed | parked | shaping | ready | promoted | dropped
// /idea promote <ref>     have the agent draft a Jira issue from the idea and link it back
//
// The `idea` tool gives the agent the same store, so "park this as an idea" works mid-conversation.
// Storage format and every write live in store.ts; the Tern sidebar uses the same module through cli.ts.
import { spawnSync } from "node:child_process";
import { basename } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { type Component, truncateToWidth } from "@oh-my-pi/pi-tui";
import {
	addInbox,
	createIdea,
	findIdea,
	type Idea,
	IdeasError,
	type IdeaStatus,
	isStatus,
	renderForContext,
	searchIdeas,
	setStatus,
	STATUSES,
	updateIdea,
	type WriteResult,
} from "./store.ts";

const MESSAGE_TYPE = "idea";
const SUBCOMMANDS = ["save", "update", "note", "open", "list", "status", "promote"];
const USAGE = "Usage: /idea save [title] | update <ref> | note <text> | open [ref] | list [query] | status <ref> <status> | promote <ref>";

const CAPSULE_SECTIONS = `## Summary
One paragraph: what this is and why it matters.
## Goal and motivation
## Decisions
Each decision with the alternatives that were rejected and why. Keep every rejected alternative.
## Evidence
Concrete file paths, symbols, commands and findings, each with the repo and commit it was checked against.
## Open questions
## Next steps
Ordered, smallest useful step first.`;

const CAPSULE_PROMPT = `Write a capsule of this conversation so a future session (weeks or months from now, with none of this context) can pick the work up. Reply with exactly this format and nothing else, no code fence around it:

title: <short title>
tags: <comma-separated lowercase tags>
status: <one of ${STATUSES.join(", ")}; usually parked>
artifacts: <comma-separated absolute paths of deliverable files produced or used in this conversation (plans, reports, HTML pages); only files that exist; empty if none>
repos: <comma-separated name=commit for every repository whose code was inspected, using commits seen in the conversation; empty if unknown>
summary: <one paragraph>
---
${CAPSULE_SECTIONS}

Be specific and factual; prefer lists. Do not invent commits or paths.`;

type Draft = {
	title: string;
	tags: string[];
	status: IdeaStatus;
	artifacts: string[];
	repos: Record<string, string>;
	summary: string;
	context: string;
};

function gitHead(cwd: string): { top: string; name: string; sha: string } | null {
	const top = spawnSync("git", ["-C", cwd, "rev-parse", "--show-toplevel"], { encoding: "utf8" });
	const sha = spawnSync("git", ["-C", cwd, "rev-parse", "--short=8", "HEAD"], { encoding: "utf8" });
	if (top.status !== 0 || sha.status !== 0) return null;
	const path = top.stdout.trim();
	return { top: path, name: basename(path), sha: sha.stdout.trim() };
}

function sessionIdOf(ctx: ExtensionContext): string[] {
	try {
		const id = ctx.sessionManager.getSessionId();
		return id ? [id] : [];
	} catch {
		return [];
	}
}

function list(value: string): string[] {
	return value
		.split(",")
		.map((s) => s.trim())
		.filter(Boolean);
}

function parseRepos(entries: string[]): Record<string, string> {
	return Object.fromEntries(
		entries
			.map((e) => e.split("=").map((s) => s.trim()))
			.filter((pair): pair is [string, string] => pair.length === 2 && pair[0] !== "" && pair[1] !== ""),
	);
}

function parseDraft(text: string): Draft {
	const split = text.search(/^---\s*$/m);
	if (split === -1) throw new IdeasError("The draft needs a `---` line between the header and the capsule");
	const header: Record<string, string> = {};
	for (const line of text.slice(0, split).split("\n")) {
		const m = /^([a-z]+):\s*(.*)$/.exec(line.trim());
		if (m) header[m[1]] = m[2].trim();
	}
	const status = header.status ?? "parked";
	return {
		title: header.title ?? "",
		tags: list(header.tags ?? "").map((t) => t.toLowerCase()),
		status: isStatus(status) ? status : "parked",
		artifacts: list(header.artifacts ?? ""),
		repos: parseRepos(list(header.repos ?? "")),
		summary: header.summary ?? "",
		context: text.slice(split).replace(/^---\s*\n?/, "").trim(),
	};
}

function describeWrite(verb: string, result: WriteResult): string {
	const { idea, skippedArtifacts } = result;
	const lines = [`${verb} idea \`${idea.id}\` (${idea.status}) at ${idea.path}`];
	if (idea.artifacts.length) lines.push(`Artifacts: ${idea.artifacts.join(", ")}`);
	if (skippedArtifacts.length) lines.push(`Not copied (missing or not a file): ${skippedArtifacts.join(", ")}`);
	return lines.join("\n");
}

class IdeaCard implements Component {
	constructor(
		private readonly lines: string[],
		private readonly compact: boolean,
	) {}
	render(width: number): string[] {
		return this.lines.map((line) => truncateToWidth(line, width));
	}
	isTranscriptBlockCompact(): boolean {
		return this.compact;
	}
	invalidate(): void {}
}

export default function ideas(pi: ExtensionAPI) {
	const z = pi.zod;

	function inject(ctx: ExtensionContext, idea: Idea): void {
		const message = {
			customType: MESSAGE_TYPE,
			content: renderForContext(idea),
			display: true,
			details: { id: idea.id, title: idea.title, status: idea.status, jira: idea.jira, created: idea.created, repos: idea.repos, artifacts: idea.artifacts.length },
		};
		if (ctx.isIdle()) pi.sendMessage(message);
		else pi.sendMessage(message, { deliverAs: "nextTurn" });
	}

	async function pick(ctx: ExtensionContext, query: string): Promise<Idea | undefined> {
		const found = searchIdeas(query);
		if (found.length === 0) {
			ctx.ui.notify(query ? `No idea matches "${query}"` : "No ideas yet: /idea save or /idea note", "info");
			return undefined;
		}
		if (!ctx.hasUI) {
			ctx.ui.notify(found.map((i) => `${i.id}  ${i.status}  ${i.title}`).join("\n"), "info");
			return undefined;
		}
		const labels = found.map((i) => `${i.title}  ·  ${i.status}${i.jira ? ` · ${i.jira}` : ""}  ·  ${i.updated}`);
		const chosen = await ctx.ui.select("Open idea", labels);
		const index = chosen === undefined ? -1 : labels.indexOf(chosen);
		return index === -1 ? undefined : found[index];
	}

	async function draftCapsule(ctx: ExtensionCommandContext, extra: string): Promise<Draft | undefined> {
		if (!ctx.runEphemeralTurn) return undefined;
		ctx.ui.notify("Summarising this session…", "info");
		const promptText = extra ? `${CAPSULE_PROMPT}\n\n${extra}` : CAPSULE_PROMPT;
		let reply: string;
		try {
			reply = (await ctx.runEphemeralTurn({ promptText, tools: false, dedupeReply: false, maxTokens: 8000 })).replyText;
		} catch {
			reply = (await ctx.runEphemeralTurn({ promptText, tools: false, dedupeReply: false })).replyText;
		}
		const reviewed = await ctx.ui.editor("Review the idea, then save and close (empty text cancels)", reply.trim());
		if (!reviewed?.trim()) return undefined;
		return parseDraft(reviewed);
	}

	function captureOrigin(ctx: ExtensionContext, draftRepos: Record<string, string>) {
		const head = gitHead(ctx.cwd);
		return {
			project: head?.top ?? null,
			repos: head ? { ...draftRepos, [head.name]: head.sha } : draftRepos,
			sessions: sessionIdOf(ctx),
		};
	}

	async function save(ctx: ExtensionCommandContext, titleHint: string): Promise<void> {
		if (!ctx.runEphemeralTurn) {
			pi.sendUserMessage(
				`Save this conversation as a new idea with the \`idea\` tool (action save)${titleHint ? `, titled "${titleHint}"` : ""}. Write the context capsule with these sections:\n\n${CAPSULE_SECTIONS}`,
			);
			return;
		}
		const draft = await draftCapsule(ctx, titleHint ? `Use this title: ${titleHint}` : "");
		if (!draft) return ctx.ui.notify("Idea not saved", "info");
		const origin = captureOrigin(ctx, draft.repos);
		const result = createIdea({
			title: titleHint || draft.title,
			tags: draft.tags,
			status: draft.status,
			body: draft.summary,
			context: draft.context,
			artifacts: draft.artifacts,
			...origin,
		});
		ctx.ui.notify(describeWrite("Saved", result), "info");
	}

	async function update(ctx: ExtensionCommandContext, ref: string): Promise<void> {
		const idea = ref ? findIdea(ref) : await pick(ctx, "");
		if (!idea) return;
		if (!ctx.runEphemeralTurn) {
			pi.sendUserMessage(`Update idea \`${idea.id}\` with the \`idea\` tool (action update): rewrite its context capsule to include what this conversation added.`);
			return;
		}
		const draft = await draftCapsule(
			ctx,
			`This updates an existing idea. Keep what still holds from its current capsule and add what this conversation changed.\n\nCurrent idea:\n\n${renderForContext(idea)}`,
		);
		if (!draft) return ctx.ui.notify("Idea not updated", "info");
		const origin = captureOrigin(ctx, draft.repos);
		const result = updateIdea(idea.id, {
			title: draft.title,
			tags: draft.tags,
			status: draft.status,
			body: draft.summary,
			context: draft.context,
			artifacts: draft.artifacts,
			repos: origin.repos,
			sessions: origin.sessions,
			project: idea.project ?? origin.project,
		});
		ctx.ui.notify(describeWrite("Updated", result), "info");
	}

	function promote(idea: Idea): void {
		pi.sendUserMessage(
			[
				`Promote idea \`${idea.id}\` ("${idea.title}") to a Jira issue.`,
				`1. Read it with the \`idea\` tool (action get, id ${idea.id}).`,
				"2. Draft a Jira issue in project CD from it: a summary line, a description (problem, proposal, acceptance criteria, the open questions), label `Backend`, assigned to me (look my account id up with atlassianUserInfo).",
				"3. Show me the draft and ask me to confirm before creating anything. Create it with createJiraIssue only after I confirm.",
				`4. Then link it back: \`idea\` tool action update, id ${idea.id}, jira <KEY>, status promoted.`,
				"Never transition, comment on or otherwise change an existing Jira issue.",
			].join("\n"),
		);
	}

	pi.registerMessageRenderer(MESSAGE_TYPE, (message, { expanded }, theme) => {
		const d = (message.details ?? {}) as { title?: string; status?: string; jira?: string | null; created?: string; repos?: Record<string, string>; artifacts?: number };
		const repos = Object.entries(d.repos ?? {}).map(([name, sha]) => `${name} ${sha}`);
		const head = `${theme.fg("accent", "◆ Idea loaded:")} ${theme.bold(d.title ?? "idea")} ${theme.fg("muted", `· ${d.status ?? "?"}${d.jira ? ` · ${d.jira}` : ""}`)}`;
		const sub = theme.fg(
			"dim",
			`  captured ${d.created ?? "?"}${repos.length ? ` at ${repos.join(", ")}` : ""} · ${d.artifacts ?? 0} artifacts · claims may be stale`,
		);
		if (!expanded) return new IdeaCard([head, sub], true);
		const body = String(message.content ?? "")
			.split("\n")
			.map((l) => theme.fg("muted", `  ${l}`));
		return new IdeaCard([head, sub, ...body], false);
	});

	pi.registerTool({
		name: "idea",
		label: "Idea",
		description:
			"Read and write Daniel's ideas store (~/ideas): parked plans, loose ideas and scratchpads that are not Jira issues yet. " +
			"Use it when the user asks to park, save, stash or keep something as an idea or scratchpad, to load or look up an idea, or to link an idea to a Jira issue.\n" +
			"Actions: save (new idea: title, context, optional body/tags/status/artifacts/repos), update (id + fields to change; context replaces the capsule), " +
			"get (id, Jira key or prefix: returns the idea and its capsule), list (optional query), note (text: one line into the inbox), set_status (id, status).\n" +
			"A save's `context` is the capsule a future session needs with none of today's context, in Markdown with these sections:\n" +
			CAPSULE_SECTIONS +
			"\n`artifacts` are absolute paths of deliverable files to copy in (plans, reports). `repos` are name=commit pairs for every repository whose code backed the evidence; " +
			"the current repo's HEAD, the project path and this session's id are added automatically. Treat file and line claims in a loaded idea as stale until re-checked.",
		parameters: z.object({
			action: z.enum(["save", "update", "get", "list", "note", "set_status"]),
			id: z.string().optional().describe("Idea id, folder name, Jira key or unique prefix (update, get, set_status)"),
			title: z.string().optional(),
			status: z.enum(STATUSES).optional(),
			tags: z.array(z.string()).optional(),
			jira: z.string().optional().describe("Jira key to link, e.g. PROJ-123 (update)"),
			body: z.string().optional().describe("A short summary paragraph; it becomes idea.md's text"),
			context: z.string().optional().describe("The capsule (save; update replaces it)"),
			artifacts: z.array(z.string()).optional().describe("Absolute file paths to copy into the idea"),
			repos: z.array(z.string()).optional().describe("name=commit pairs, e.g. my-app=8bb7170"),
			query: z.string().optional().describe("Search words (list)"),
			text: z.string().optional().describe("The inbox line (note)"),
		}),
		approval: "read",
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const fail = (text: string) => ({ content: [{ type: "text" as const, text }], isError: true });
			const ok = (text: string, details?: unknown) => ({ content: [{ type: "text" as const, text }], details });
			try {
				switch (params.action) {
					case "save": {
						if (!params.title?.trim() || !params.context?.trim()) return fail("save needs a title and a context capsule");
						const origin = captureOrigin(ctx, parseRepos(params.repos ?? []));
						const result = createIdea({
							title: params.title,
							status: params.status ?? "parked",
							tags: params.tags,
							jira: params.jira ?? null,
							body: params.body,
							context: params.context,
							artifacts: params.artifacts,
							...origin,
						});
						return ok(describeWrite("Saved", result), { id: result.idea.id });
					}
					case "update": {
						if (!params.id) return fail("update needs an id");
						const repos = parseRepos(params.repos ?? []);
						const origin = params.context ? captureOrigin(ctx, repos) : { repos, sessions: sessionIdOf(ctx) };
						const result = updateIdea(params.id, {
							title: params.title,
							status: params.status,
							tags: params.tags,
							jira: params.jira,
							body: params.body,
							context: params.context,
							artifacts: params.artifacts,
							repos: origin.repos,
							sessions: origin.sessions,
						});
						return ok(describeWrite("Updated", result), { id: result.idea.id });
					}
					case "get":
						if (!params.id) return fail("get needs an id");
						return ok(renderForContext(findIdea(params.id)));
					case "list": {
						const found = searchIdeas(params.query ?? "");
						return ok(
							found.length
								? found.map((i) => `${i.id} · ${i.status}${i.jira ? ` · ${i.jira}` : ""} · ${i.updated} · ${i.title}`).join("\n")
								: "No ideas match.",
						);
					}
					case "note": {
						if (!params.text?.trim()) return fail("note needs text");
						const item = addInbox(params.text);
						return ok(`Noted in inbox.md:${item.line}: ${item.text}`);
					}
					case "set_status": {
						if (!params.id || !params.status) return fail("set_status needs an id and a status");
						const idea = setStatus(params.id, params.status);
						return ok(`${idea.id} is now ${idea.status}`);
					}
				}
			} catch (error) {
				if (error instanceof IdeasError) return fail(error.message);
				throw error;
			}
		},
	});

	pi.registerCommand("idea", {
		description: "Ideas store: save | update | note | open | list | status | promote",
		getArgumentCompletions: (prefix) => {
			const [sub, ...rest] = prefix.split(/\s+/);
			if (rest.length === 0) return SUBCOMMANDS.filter((s) => s.startsWith(sub)).map((s) => ({ value: `${s} `, label: s }));
			if (["open", "update", "status", "promote"].includes(sub) && rest.length === 1) {
				try {
					return searchIdeas("")
						.filter((i) => i.id.startsWith(rest[0]))
						.map((i) => ({ value: `${sub} ${i.id} `, label: i.id, description: i.title }));
				} catch {
					return [];
				}
			}
			if (sub === "status" && rest.length === 2) {
				return STATUSES.filter((s) => s.startsWith(rest[1])).map((s) => ({ value: `${sub} ${rest[0]} ${s}`, label: s }));
			}
			return [];
		},
		handler: async (args, ctx) => {
			const [sub = "", ...restWords] = args.trim().split(/\s+/);
			const rest = restWords.join(" ").trim();
			try {
				switch (sub) {
					case "save":
						return await save(ctx, rest);
					case "update":
						return await update(ctx, rest);
					case "note": {
						if (!rest) return ctx.ui.notify("Usage: /idea note <text>", "warning");
						const item = addInbox(rest);
						return ctx.ui.notify(`Noted (inbox.md:${item.line})`, "info");
					}
					case "open":
					case "list": {
						const idea = sub === "open" && rest ? findIdea(rest) : await pick(ctx, sub === "list" ? rest : "");
						if (idea) inject(ctx, idea);
						return;
					}
					case "status": {
						const [ref, status] = restWords;
						if (!ref || !status || !isStatus(status)) return ctx.ui.notify(`Usage: /idea status <ref> <${STATUSES.join(" | ")}>`, "warning");
						const idea = setStatus(ref, status);
						return ctx.ui.notify(`${idea.id} is now ${idea.status}`, "info");
					}
					case "promote": {
						const idea = rest ? findIdea(rest) : await pick(ctx, "");
						if (idea) promote(idea);
						return;
					}
					default:
						return ctx.ui.notify(USAGE, sub ? "warning" : "info");
				}
			} catch (error) {
				if (error instanceof IdeasError) return ctx.ui.notify(error.message, "warning");
				throw error;
			}
		},
	});
}
