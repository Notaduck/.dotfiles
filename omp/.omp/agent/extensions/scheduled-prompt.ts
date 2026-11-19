// Runs a prompt in this chat at a set time, like Claude Code's scheduled prompts.
// Lives inside the omp process only: no launchd, cron or OS jobs. The timer stops when omp closes;
// resuming the chat re-arms pending prompts and runs any that came due while it was closed.
// The agent schedules with the `schedule_prompt` tool; you manage them with `/schedule`.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const ENTRY = "dk.dagu.scheduled-prompt";
const TICK_MS = 30_000;

type Status = "pending" | "fired" | "cancelled";
interface Scheduled {
	id: string;
	at: string;
	prompt: string;
	status: Status;
}

function parseWhen(input: string, now = new Date()): Date | null {
	const hhmm = /^(\d{1,2}):(\d{2})$/.exec(input.trim());
	if (hhmm) {
		const d = new Date(now);
		d.setHours(Number(hhmm[1]), Number(hhmm[2]), 0, 0);
		if (d <= now) d.setDate(d.getDate() + 1);
		return d;
	}
	const t = Date.parse(input);
	return Number.isNaN(t) ? null : new Date(t);
}

const local = (iso: string) =>
	new Date(iso).toLocaleString("en-GB", { dateStyle: "short", timeStyle: "short" });

export default function scheduledPrompt(pi: ExtensionAPI) {
	const z = pi.zod;
	const items = new Map<string, Scheduled>();

	const save = (item: Scheduled) => {
		items.set(item.id, item);
		pi.appendEntry(ENTRY, item);
	};

	const pending = () => [...items.values()].filter((i) => i.status === "pending").sort((a, b) => a.at.localeCompare(b.at));

	const schedule = (when: string, prompt: string): Scheduled | string => {
		const at = parseWhen(when);
		if (!at) return `Could not read the time "${when}". Use HH:MM (next occurrence) or an ISO date-time.`;
		if (at.getTime() <= Date.now()) return `${local(at.toISOString())} is in the past.`;
		if (!prompt.trim()) return "The prompt is empty.";
		const item: Scheduled = { id: Math.random().toString(36).slice(2, 8), at: at.toISOString(), prompt: prompt.trim(), status: "pending" };
		save(item);
		return item;
	};

	const fireDue = () => {
		for (const item of pending()) {
			if (new Date(item.at).getTime() > Date.now()) continue;
			save({ ...item, status: "fired" });
			const late = Math.round((Date.now() - new Date(item.at).getTime()) / 60_000);
			const header = `[Scheduled prompt ${item.id}, set for ${local(item.at)}${late > 5 ? `, running ${late} min late` : ""}]`;
			pi.sendUserMessage(`${header}\n\n${item.prompt}`, { deliverAs: "aside", attribution: "agent" });
		}
	};

	const rebuild = (ctx: { sessionManager: { getBranch(): Array<{ type: string; customType?: string; data?: unknown }> } }) => {
		items.clear();
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === ENTRY) {
				const item = entry.data as Scheduled;
				items.set(item.id, item);
			}
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		rebuild(ctx);
		ctx.setInterval(fireDue, TICK_MS);
		fireDue();
	});
	pi.on("session_switch", async (_event, ctx) => rebuild(ctx));

	pi.registerTool({
		name: "schedule_prompt",
		label: "Schedule Prompt",
		description:
			"Run a prompt in this chat at a set time, e.g. a health check tomorrow at 08:30. Use this when the user asks " +
			"for something to happen later. It runs inside omp only (never launchd/cron/OS jobs) and needs this chat to " +
			"be open or resumed; a prompt that came due while omp was closed runs on resume. Write the prompt so it is " +
			"self-contained: what to check, how, and what to report.",
		parameters: z.object({
			at: z.string().describe("Local `HH:MM` (next occurrence) or an ISO date-time, e.g. `2026-11-11T08:30:00+01:00`"),
			prompt: z.string().describe("The full prompt to run at that time"),
		}),
		approval: "write",
		async execute(_toolCallId, params) {
			const res = schedule(params.at, params.prompt);
			if (typeof res === "string") return { content: [{ type: "text", text: res }], isError: true };
			return {
				content: [{ type: "text", text: `Scheduled ${res.id} for ${local(res.at)}. Cancel with /schedule cancel ${res.id}.` }],
				details: res,
			};
		},
	});

	pi.registerCommand("schedule", {
		description: "Scheduled prompts: /schedule [list] | /schedule cancel <id> | /schedule <HH:MM|ISO> <prompt>",
		handler: async (args, ctx) => {
			const text = (args ?? "").trim();
			if (!text || text === "list") {
				const list = pending();
				ctx.ui.notify(list.length ? list.map((i) => `${i.id}  ${local(i.at)}  ${i.prompt.slice(0, 80)}`).join("\n") : "No scheduled prompts.", "info");
				return;
			}
			const cancel = /^cancel\s+(\S+)$/.exec(text);
			if (cancel) {
				const item = items.get(cancel[1]);
				if (!item || item.status !== "pending") return ctx.ui.notify(`No pending prompt ${cancel[1]}.`, "warning");
				save({ ...item, status: "cancelled" });
				return ctx.ui.notify(`Cancelled ${item.id}.`, "info");
			}
			const [when, ...rest] = text.split(/\s+/);
			const res = schedule(when, rest.join(" "));
			if (typeof res === "string") return ctx.ui.notify(res, "warning");
			ctx.ui.notify(`Scheduled ${res.id} for ${local(res.at)}.`, "info");
		},
	});
}
