// `ideas` CLI over store.ts, for the Tern sidebar and the shell. Run with Node >= 23.6 (type stripping).
//
//   ideas init                       create ~/ideas (git repo, inbox, README)
//   ideas list [--json] [query...]   ideas, newest first; --json prints the index entries
//   ideas show <ref> [--json]        one idea (id, folder, Jira key or unique prefix)
//   ideas context <ref>              what /idea open puts into a chat
//   ideas status <ref> <status>      seed | parked | shaping | ready | promoted | dropped
//   ideas note <text...>             append a line to inbox.md
//   ideas reindex                    rewrite index.json
//   ideas path [ref]                 the store root, or an idea's folder
import {
	addInbox,
	ensureStore,
	findIdea,
	IdeasError,
	isStatus,
	reindex,
	renderForContext,
	root,
	searchIdeas,
	setStatus,
	STATUSES,
} from "./store.ts";

const USAGE = `usage: ideas <init | list [--json] [query] | show <ref> [--json] | context <ref> | status <ref> <status> | note <text> | reindex | path [ref]>`;

function main(argv: string[]): number {
	const json = argv.includes("--json");
	const args = argv.filter((a) => a !== "--json");
	const [command, ...rest] = args;
	switch (command) {
		case "init":
			console.log(ensureStore());
			return 0;
		case "list": {
			const ideas = searchIdeas(rest.join(" "));
			if (json) {
				const ids = new Set(ideas.map((i) => i.id));
				console.log(JSON.stringify(reindex().ideas.filter((e) => ids.has(e.id)), null, 2));
			} else {
				for (const i of ideas) console.log(`${i.id.padEnd(36)} ${i.status.padEnd(9)} ${i.updated}  ${i.title}`);
			}
			return 0;
		}
		case "show": {
			const idea = findIdea(rest.join(" "));
			console.log(json ? JSON.stringify(idea, null, 2) : `${idea.path}\n\n${idea.body}`);
			return 0;
		}
		case "context":
			console.log(renderForContext(findIdea(rest.join(" "))));
			return 0;
		case "status": {
			const [ref, status] = rest;
			if (!ref || !status || !isStatus(status)) throw new IdeasError(`usage: ideas status <ref> <${STATUSES.join(" | ")}>`);
			const idea = setStatus(ref, status);
			console.log(`${idea.id}: ${idea.status}`);
			return 0;
		}
		case "note": {
			const item = addInbox(rest.join(" "));
			console.log(`inbox.md:${item.line} ${item.text}`);
			return 0;
		}
		case "reindex":
			ensureStore();
			console.log(`${reindex().ideas.length} ideas indexed`);
			return 0;
		case "path":
			console.log(rest.length ? findIdea(rest.join(" ")).path : root());
			return 0;
		default:
			console.error(USAGE);
			return 2;
	}
}

try {
	process.exitCode = main(process.argv.slice(2));
} catch (error) {
	console.error(error instanceof IdeasError ? error.message : error);
	process.exitCode = 1;
}
