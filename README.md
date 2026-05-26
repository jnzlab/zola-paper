# zola-paper

**zola-paper** is a full rewrite of my portfolio, originally built on the [AstroPaper](https://github.com/satnaing/astro-paper) theme. I liked AstroPaper’s look and layout, but I wanted the speed and simplicity of a Rust-backed static site generator — so I rebuilt the entire project in [Zola](https://www.getzola.org/).

The name **zola-paper** reflects that lineage: same AstroPaper-inspired design and features, implemented on Zola instead of Astro. The previous Astro version lives in `https://github.com/jnzlab/jameel`; this repo is the Zola port, with matching UI, search (Pagefind), GitHub highlights, and the rest of the site behavior.

## GitHub token

Copy the example env file and add your token (same as jameel's `.env`):

```bash
cp .env.example .env
# edit .env and set GITHUB_TOKEN=ghp_...
```

`.env` is gitignored — never commit it.

## Commands

Install dependencies (one-time):

```bash
npm install
```

Fetch highlighted GitHub repos, then build:

```bash
./build.sh
```

Local dev (fetch + build + serve):

```bash
./serve.sh
```

Search uses [Pagefind](https://pagefind.app/) (same as the Astro site): full-text indexing with keyword highlighting, sub-results per section, and result counts. `./build.sh` runs Pagefind after `zola build`.

## What gets generated (not committed)

These paths are in `.gitignore` and recreated on every build:

| Path | Source |
|------|--------|
| `public/` | Zola + Pagefind output |
| `static/pagefind-ui/` | Copied from `@pagefind/default-ui` |
| `data/github_repos.json` | Fetched from GitHub API |

## Deploy to Cloudflare Pages

This site is a **static** Zola build. Cloudflare Pages is a good fit.

### Option A — Git integration (recommended)

1. Push this repo to GitHub (or GitLab).
2. In the [Cloudflare dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**.
3. Select the repository and configure:

| Setting | Value |
|---------|--------|
| **Production branch** | `main` (or your default branch) |
| **Root directory** | `zola-paper` if the repo is the `beta` monorepo; leave blank if this folder is the repo root |
| **Build command** | `bash cloudflare-build.sh` |
| **Build output directory** | `public` |

4. Under **Settings → Environment variables**, add:

| Variable | Notes |
|----------|--------|
| `GITHUB_TOKEN` | GitHub PAT with `public_repo` (or `repo` for private repos). Used at build time for the highlighted repos section. Mark as **Encrypted**. |
| `NODE_VERSION` | `20` (optional; Pages sets Node by default) |
| `ZOLA_VERSION` | `0.19.2` (optional; used by `scripts/install-zola.sh`) |

5. Save and deploy. Each push to the production branch rebuilds and publishes.

**Custom domain:** Pages → your project → **Custom domains** → add `jnzlab.io` (or your domain). Cloudflare will configure DNS if the zone is on Cloudflare.

**Preview deployments:** Every PR/branch gets its own preview URL automatically.

### Option B — Manual deploy with Wrangler

After a local build:

```bash
npm ci
./build.sh
npx wrangler pages deploy public --project-name=jnzlab
```

Install Wrangler once: `npm install -g wrangler` and run `wrangler login`.

### Build notes for Cloudflare

- `cloudflare-build.sh` installs Zola (if missing), runs `npm ci`, then `./build.sh`.
- `GITHUB_TOKEN` must be set in the Pages dashboard — the build fetches repo metadata and will fail or show a fallback without it.
- Pagefind runs as part of `./build.sh`; search works on the deployed site without extra config.
- No Workers or server-side runtime is required — Pages serves the `public/` folder from the edge.

### Redirects / 404

Zola emits `404.html` at the site root. Cloudflare Pages serves it automatically for missing routes on static deployments.
