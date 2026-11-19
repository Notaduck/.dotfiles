// Lets the agent title its chat after the Jira issue it works on, as `[PROJ-123] Summary`.
// The title is omp's session name: Tern shows it on the chat's tab, `/sessions` and resume list it.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function sessionTitle(pi: ExtensionAPI) {
	const z = pi.zod;

	pi.registerTool({
		name: "set_session_title",
		label: "Set Session Title",
		description:
			"Set this chat's title (shown on its tab). Use it whenever the chat is about a Jira issue: as soon as " +
			"you know the issue's key and summary (the user named a key like PROJ-123, or you created the issue), " +
			"call it with `[KEY] Summary`, the issue's summary as Jira has it, e.g. " +
			"`[PROJ-123] Automate releases with semantic-release`. Call it again when the chat moves to another " +
			"issue. Do not use it for chats without a Jira issue; those keep their automatic title.",
		parameters: z.object({
			title: z.string().describe("`[KEY] Summary`, e.g. `[PROJ-123] Automate releases with semantic-release`"),
		}),
		loadMode: "essential",
		approval: "read",
		async execute(_toolCallId, params) {
			const title = params.title.replace(/\s+/g, " ").trim();
			if (!title) {
				return { content: [{ type: "text", text: "Title is empty; nothing renamed." }], isError: true };
			}
			await pi.setSessionName(title);
			return { content: [{ type: "text", text: `Chat titled: ${title}` }], details: { title } };
		},
	});
}
