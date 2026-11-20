// After each agent run, draws one dim row with when you sent the prompt and when omp finished replying:
//   ↳ sent 14:02:11 · replied 14:03:40 · 1m29s
// The row is saved with the session (so it survives resume) but never sent to the model.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { type Component, truncateToWidth } from "@oh-my-pi/pi-tui";

const MESSAGE_TYPE = "turn-times";

type Times = { sentAt?: number; repliedAt: number };

function clock(ms: number): string {
	const at = new Date(ms);
	const time = at.toLocaleTimeString("en-GB", { hour12: false });
	if (at.toDateString() === new Date().toDateString()) return time;
	return `${at.toLocaleDateString("en-CA")} ${time}`;
}

function duration(ms: number): string {
	const s = Math.max(0, Math.round(ms / 1000));
	if (s < 60) return `${s}s`;
	const m = Math.floor(s / 60);
	if (m < 60) return `${m}m${String(s % 60).padStart(2, "0")}s`;
	return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}m`;
}

function describe({ sentAt, repliedAt }: Times): string {
	if (sentAt === undefined) return `↳ replied ${clock(repliedAt)}`;
	return `↳ sent ${clock(sentAt)} · replied ${clock(repliedAt)} · ${duration(repliedAt - sentAt)}`;
}

class TimesRow implements Component {
	constructor(private readonly line: string) {}
	render(width: number): string[] {
		return [truncateToWidth(this.line, width)];
	}
	isTranscriptBlockCompact(): boolean {
		return true;
	}
	invalidate(): void {}
}

export default function turnTimes(pi: ExtensionAPI) {
	// First user message since the last run ended: the prompt that started this run.
	// Steers typed mid-run come later and don't move it.
	let sentAt: number | undefined;

	pi.on("message_end", (event, ctx) => {
		if (ctx.agent.kind !== "main" || event.message.role !== "user") return;
		sentAt ??= event.message.timestamp;
	});

	pi.on("agent_end", (_event, ctx) => {
		if (ctx.agent.kind !== "main") return;
		const times: Times = { sentAt, repliedAt: Date.now() };
		sentAt = undefined;
		pi.sendMessage({
			customType: MESSAGE_TYPE,
			content: describe(times),
			display: true,
			excludeFromContext: true,
			details: times,
		});
	});

	pi.registerMessageRenderer(MESSAGE_TYPE, (message, _options, theme) => {
		const times = message.details as Times | undefined;
		return new TimesRow(theme.fg("dim", times ? describe(times) : String(message.content)));
	});
}
