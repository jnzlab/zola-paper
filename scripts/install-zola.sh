#!/usr/bin/env bash
# Installs Zola on Linux CI (Cloudflare Pages, GitHub Actions, etc.) when not already on PATH.
set -euo pipefail

if command -v zola >/dev/null 2>&1; then
  exit 0
fi

ZOLA_VERSION="${ZOLA_VERSION:-0.19.2}"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ZOLA_ARCH="x86_64-unknown-linux-gnu" ;;
  aarch64|arm64) ZOLA_ARCH="aarch64-unknown-linux-gnu" ;;
  *)
    echo "Unsupported architecture for automatic Zola install: $ARCH" >&2
    exit 1
    ;;
esac

TARBALL="zola-v${ZOLA_VERSION}-${ZOLA_ARCH}.tar.gz"
URL="https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/${TARBALL}"

echo "Installing Zola v${ZOLA_VERSION} from ${URL}..."
curl -sSfL "$URL" | tar xz -C /tmp
install -m 755 "/tmp/zola" /usr/local/bin/zola 2>/dev/null || {
  mkdir -p "${HOME}/.local/bin"
  install -m 755 "/tmp/zola" "${HOME}/.local/bin/zola"
  export PATH="${HOME}/.local/bin:${PATH}"
}
zola --version
