#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
node scripts/fetch-github-repos.mjs
node scripts/copy-pagefind-ui.mjs
# Zola 0.19.x expects config.toml; newer versions use zola.toml
if [ ! -f config.toml ] && [ -f zola.toml ]; then
  ln -sf zola.toml config.toml
  trap 'rm -f config.toml' EXIT
fi
BASE_URL_ARGS=()
if [ -n "${ZOLA_BASE_URL:-}" ]; then
  BASE_URL_ARGS=(-u "$ZOLA_BASE_URL")
fi
zola build "${BASE_URL_ARGS[@]}" "$@"
npx pagefind --site public
