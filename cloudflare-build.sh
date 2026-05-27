#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash scripts/install-zola.sh
npm ci
./build.sh
