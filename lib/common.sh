#!/usr/bin/env bash
# Shared helpers: paths, colours, logging, config loading.
# Sourced by install.sh, dpibypass and lib/zapret.sh.

set -o pipefail

# Resolve repo root relative to this file so it works from any CWD.
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$_LIB_DIR")"

# Load user config.
if [ -f "$ROOT_DIR/config.env" ]; then
  # shellcheck disable=SC1091
  . "$ROOT_DIR/config.env"
fi

# Sensible fallbacks in case config.env is trimmed.
: "${ZAPRET_REPO:=https://github.com/bol-van/zapret2}"
: "${ZAPRET_REF:=main}"
: "${ZAPRET_BASE:=/opt/zapret2}"
: "${PORTS_TCP:=443,1443,8443}"
: "${PORTS_UDP:=443,1443,8443}"
: "${FWTYPE:=nftables}"
: "${TEST_TARGET:=}"
: "${DPIBYPASS_BASE:=/opt/dpi-bypass}"

STRATEGY_DIR="$ROOT_DIR/strategies"
ACTIVE_FILE="$ROOT_DIR/.active"

# --- colours (disabled when not a terminal) -------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_CYN=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GRN=; C_YEL=; C_BLU=; C_CYN=
fi

info() { printf '%s\n' "${C_CYN}::${C_RESET} $*"; }
step() { printf '%s\n' "${C_BLU}${C_BOLD}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }
ok()   { printf '%s\n' "${C_GRN}✔${C_RESET} $*"; }
warn() { printf '%s\n' "${C_YEL}!${C_RESET} $*" >&2; }
err()  { printf '%s\n' "${C_RED}✗${C_RESET} $*" >&2; }
die()  { err "$*"; exit 1; }

# Re-exec under sudo if not root.
require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    info "Root required — re-running with sudo…"
    exec sudo -E "$@"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }
