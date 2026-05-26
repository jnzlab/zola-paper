import { cpSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkg = join(root, "node_modules/@pagefind/default-ui");
const out = join(root, "static/pagefind-ui");

mkdirSync(out, { recursive: true });
cpSync(join(pkg, "css/ui.css"), join(out, "ui.css"));
cpSync(join(pkg, "npm_dist/mjs/ui-core.mjs"), join(out, "ui-core.mjs"));
