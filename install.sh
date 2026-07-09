#!/usr/bin/env bash
# dpi-bypass one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB/dpi-bypass/main/install.sh | sudo bash
#
# or, if your repo differs from the default below:
#   DPIBYPASS_REPO=https://github.com/you/dpi-bypass DPIBYPASS_REF=main \
#     bash <(curl -fsSL https://raw.githubusercontent.com/you/dpi-bypass/main/install.sh)
set -euo pipefail

# >>> EDIT THIS to your GitHub repo before publishing (or pass DPIBYPASS_REPO) <<<
DPIBYPASS_REPO="${DPIBYPASS_REPO:-https://github.com/YOUR_GITHUB/dpi-bypass}"
DPIBYPASS_REF="${DPIBYPASS_REF:-main}"
DEST="${DPIBYPASS_BASE:-/opt/dpi-bypass}"

red()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
blu()  { printf '\033[34m\033[1m==> %s\033[0m\n' "$*"; }

# Must be root (curl | sudo bash already is; otherwise re-exec).
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  blu "Root required — re-running under sudo…"
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
blu "Installing prerequisites (git, curl)"
apt-get update -qq
apt-get install -y -qq git curl ca-certificates >/dev/null

# Figure out where the wrapper source is: run from a local clone, or fetch it.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/dpibypass" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  blu "Using local wrapper source: $SRC"
else
  case "$DPIBYPASS_REPO" in
    *YOUR_GITHUB*)
      red "install.sh is running from a pipe but DPIBYPASS_REPO is still the placeholder."
      red "Edit DPIBYPASS_REPO in install.sh to point at your fork, or run:"
      red "  DPIBYPASS_REPO=https://github.com/you/dpi-bypass bash <(curl -fsSL .../install.sh)"
      exit 1 ;;
  esac
  TMP="$(mktemp -d)"
  blu "Cloning wrapper from $DPIBYPASS_REPO ($DPIBYPASS_REF)"
  git clone --depth=1 -b "$DPIBYPASS_REF" "$DPIBYPASS_REPO" "$TMP"
  SRC="$TMP"
fi

# Install the wrapper to $DEST (preserving an existing config.env).
blu "Installing wrapper to $DEST"
mkdir -p "$DEST"
if [ -f "$DEST/config.env" ] && [ "$SRC" != "$DEST" ]; then
  cp "$DEST/config.env" "$DEST/.config.env.bak"
fi
if [ "$SRC" != "$DEST" ]; then
  cp -a "$SRC/." "$DEST/"
fi
[ -f "$DEST/.config.env.bak" ] && mv "$DEST/.config.env.bak" "$DEST/config.env"
chmod +x "$DEST/dpibypass" "$DEST/install.sh" 2>/dev/null || true

# Symlink the CLI onto PATH.
ln -sf "$DEST/dpibypass" /usr/local/bin/dpibypass
grn "Installed CLI: dpibypass"

# Build zapret2 from source via the wrapper's own logic.
# shellcheck disable=SC1091
. "$DEST/lib/common.sh"
# shellcheck disable=SC1091
. "$DEST/lib/zapret.sh"
zap_install

echo
grn "Done. Next:"
echo "  1) Check ports in $DEST/config.env match your VLESS/SS/Hysteria links."
echo "  2) Run:  dpibypass          (interactive menu)"
echo "     or:   dpibypass test     (try strategies until a link works)"
echo

# Drop straight into the menu when we have a terminal.
if [ -t 0 ] && [ -t 1 ]; then
  exec dpibypass
fi
