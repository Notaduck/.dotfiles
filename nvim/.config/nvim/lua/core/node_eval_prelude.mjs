// Loaded via `node --import` before the instrumented buffer runs.
// Emits one marker-prefixed JSON line per result on stdout; node_eval.lua parses them.
import { createRequire, registerHooks } from "node:module";
import { realpathSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { inspect } from "node:util";

const MARK = "\u0000NODE_EVAL\u0000";
const TARGET = pathToFileURL(realpathSync(process.env.NODE_EVAL_FILE)).href;
const BASE = pathToFileURL(process.env.NODE_EVAL_BASE).href;
const write = process.stdout.write.bind(process.stdout);

// Resolve imports from the temp file as if they came from the real buffer path,
// so relative paths and the project's node_modules work.
registerHooks({
  resolve(specifier, context, next) {
    if (context.parentURL === TARGET) context = { ...context, parentURL: BASE };
    return next(specifier, context);
  },
});

// CommonJS conveniences (the buffer runs as ESM).
globalThis.require = createRequire(BASE);
globalThis.__filename = fileURLToPath(BASE);
globalThis.__dirname = dirname(globalThis.__filename);

const show = (v) => inspect(v, { depth: 2, breakLength: Infinity, maxArrayLength: 20, maxStringLength: 200 });
const fmt = (v) => (typeof v === "string" ? v : show(v));

const emit = (line, kind, text) => write(MARK + JSON.stringify({ line, kind, text }) + "\n");

const lineOf = (stack = "") => {
  for (const l of stack.split("\n")) {
    const i = l.indexOf(TARGET + ":");
    if (i !== -1) return Number(l.slice(i + TARGET.length + 1).split(":")[0]) - 1;
  }
  return null;
};

globalThis.__ne = (line, names, values) => {
  emit(line, "value", names ? names.map((n, i) => `${n} = ${show(values[i])}`).join(", ") : show(values[0]));
  return values[0];
};
globalThis.__nev = (line, value) => {
  if (value !== undefined) emit(line, "value", show(value));
  return value;
};

for (const method of ["log", "info", "debug", "warn", "error", "table", "dir"]) {
  console[method] = (...args) => {
    const line = lineOf(new Error().stack);
    if (line !== null) emit(line, method === "error" || method === "warn" ? "error" : "log", args.map(fmt).join(" "));
  };
}

const onError = (err) => {
  const line = lineOf(err?.stack) ?? 0;
  emit(line, "error", err instanceof Error ? `${err.name}: ${err.message}` : `Uncaught ${fmt(err)}`);
  process.exit(1);
};
process.on("uncaughtException", onError);
process.on("unhandledRejection", onError);
