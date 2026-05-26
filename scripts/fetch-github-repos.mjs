import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const refsPath = join(root, "data/portfolio_github_repos.json");
const outPath = join(root, "data/github_repos.json");

/** @typedef {{ owner: string; repo: string }} PortfolioRepoRef */

/** @param {string | null | undefined} iso */
function formatPushedAt(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

/** @param {string | undefined} token */
function apiHeaders(token) {
  const headers = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

/** @param {PortfolioRepoRef} ref @param {Record<string, string>} headers */
async function fetchOneRepo(ref, headers) {
  const url = `https://api.github.com/repos/${encodeURIComponent(ref.owner)}/${encodeURIComponent(ref.repo)}`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    console.warn(`Skipping ${ref.owner}/${ref.repo}: HTTP ${res.status}`);
    return null;
  }
  const json = await res.json();
  return {
    name: json.name,
    full_name: json.full_name,
    description: json.description,
    html_url: json.html_url,
    homepage: json.homepage?.trim() ? json.homepage : null,
    language: json.language,
    fork: json.fork,
    topics: Array.isArray(json.topics) ? json.topics : [],
    pushed_at_label: formatPushedAt(json.pushed_at),
  };
}

async function main() {
  /** @type {PortfolioRepoRef[]} */
  const refs = JSON.parse(readFileSync(refsPath, "utf8"));
  const token = process.env.GITHUB_TOKEN;
  const headers = apiHeaders(token);

  const results = await Promise.all(refs.map(ref => fetchOneRepo(ref, headers)));
  const repos = results.filter(Boolean);

  writeFileSync(outPath, `${JSON.stringify(repos, null, 2)}\n`);
  console.log(`Wrote ${repos.length} repo(s) to data/github_repos.json`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
