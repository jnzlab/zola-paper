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
zola build "$@"
npx pagefind --site public
