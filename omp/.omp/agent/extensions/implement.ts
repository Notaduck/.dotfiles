// /implement <KEY>: start implementing a Jira issue in this repo. Enters plan mode, then has the agent read the issue
// (and a linked idea from ~/ideas, if any) and write a plan for approval. Tern's Jira Sprint "Implement" button opens
// a worktree on `feature/<KEY>_<slug>` and starts omp there with this command.
//
// The Jira issue is read only: the agent never moves, assigns, comments on or edits it.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const KEY = /^[A-Z][A-Z0-9]+-\d+$/;

function prompt(key: string): string {
	return [
		`Implement Jira issue ${key} in this repository.`,
		"",
		`1. Read the issue: getJiraIssue for ${key}, its comments (listJiraIssueComments), and its parent and linked issues. Note the acceptance criteria. Sub-tasks that only track a deployment (dev, stg, prod) are closed by the release; plan no work for them.`,
		`2. Call set_session_title with \`[${key}] <summary as Jira has it>\`.`,
		`3. Check for a linked idea: the \`idea\` tool with action get and id ${key}. If one exists, use its capsule as background; its file and line claims are pinned to old commits, so re-check them.`,
		`4. Check the branch with \`git branch --show-current\`. Expect \`feature/${key}_<camelCaseSlug>\`; if it is anything else, say so at the top of the plan. Don't create or switch branches yourself. Look for work already done: \`git log --oneline origin/develop..HEAD\` (check \`git cherry -v origin/develop HEAD\` too, develop may have been rewritten) and an open pull request for the branch (\`gh pr list --head <branch> --state all\`; if gh can't see the repository, pick the account with access from \`gh auth status\` and prefix \`GH_TOKEN=$(gh auth token --user <account>)\`). If there is earlier work or a PR, the plan continues it: say what is done, what is left (review comments, failing checks, rebase onto origin/develop), and don't redo it.`,
		"5. If there is a package.json and no node_modules, run `npm ci`.",
		"6. Read AGENTS.md and the `.claude/rules` files for the areas you will touch.",
		"7. Write the implementation plan: what changes where, tests, risks, and what you could not verify. Wait for my approval before editing anything.",
		"",
		`Never transition, assign, comment on or edit ${key} or any other Jira issue.`,
	].join("\n");
}

export default function implement(pi: ExtensionAPI) {
	pi.registerCommand("implement", {
		description: "Plan the implementation of a Jira issue: /implement PROJ-123",
		handler: async (args, ctx) => {
			const key = args.trim().toUpperCase();
			if (!KEY.test(key)) return ctx.ui.notify("Usage: /implement <JIRA-KEY>, e.g. /implement PROJ-123", "warning");
			const entered = await ctx.sessionModes?.set({ mode: "plan", action: "enter" });
			if (entered && !entered.ok && entered.code !== "conflict") ctx.ui.notify(`Plan mode not entered: ${entered.message}`, "warning");
			pi.sendUserMessage(prompt(key));
		},
	});
}
