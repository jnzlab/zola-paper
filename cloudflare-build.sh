#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash scripts/install-zola.sh
npm ci
# Use stable Pages URL until jnzlab.io custom domain is configured (override in dashboard)
export ZOLA_BASE_URL="${ZOLA_BASE_URL:-https://zola-paper.pages.dev}"
./build.sh
