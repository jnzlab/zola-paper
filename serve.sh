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
export ZOLA_BASE_URL="${ZOLA_BASE_URL:-http://127.0.0.1:1111}"
./build.sh
exec zola serve "$@"
