#!/usr/bin/env bash
# zapret2 lifecycle: fetch, build, configure, run.
# Depends on lib/common.sh being sourced first.

SYSV="$ZAPRET_BASE/init.d/sysv/zapret2"
UNIT_SRC="$ZAPRET_BASE/init.d/systemd/zapret2.service"
NFQWS_BIN="$ZAPRET_BASE/nfq2/nfqws2"

# True once zapret2 is cloned and the nfqws2 binary is built.
zap_built() { [ -x "$NFQWS_BIN" ] || [ -x "$ZAPRET_BASE/binaries/my/nfqws2" ]; }

# Clone (or update) zapret2 and build it from source.
zap_install() {
  export DEBIAN_FRONTEND=noninteractive

  step "Installing base packages"
  apt-get update -qq
  apt-get install -y -qq git curl ca-certificates >/dev/null

  if [ -d "$ZAPRET_BASE/.git" ]; then
    step "Updating zapret2 ($ZAPRET_BASE)"
    git -C "$ZAPRET_BASE" fetch --depth=1 origin "$ZAPRET_REF" -q || true
    git -C "$ZAPRET_BASE" reset --hard "origin/$ZAPRET_REF" -q || true
  else
    step "Cloning zapret2 from $ZAPRET_REPO"
    git clone --depth=1 -b "$ZAPRET_REF" "$ZAPRET_REPO" "$ZAPRET_BASE"
  fi

  step "Installing build prerequisites (zapret2 install_prereq.sh)"
  yes '' | "$ZAPRET_BASE/install_prereq.sh" || warn "install_prereq.sh returned non-zero (often fine)"

  step "Building binaries from source (zapret2 install_bin.sh)"
  "$ZAPRET_BASE/install_bin.sh" || die "install_bin.sh failed — check compiler output above"

  zap_built || die "Build finished but nfqws2 binary not found at $NFQWS_BIN"
  ok "zapret2 built"
}

# Expand %TCP% / %UDP% placeholders in a strategy's option string.
zap_expand() {
  local opt="$1"
  opt="${opt//%TCP%/$PORTS_TCP}"
  opt="${opt//%UDP%/$PORTS_UDP}"
  printf '%s' "$opt"
}

# Write NFQWS2_OPT + ports into zapret2's config as a managed block.
# The block is appended last, so it overrides config.default's values.
zap_write_config() {
  local opt; opt="$(zap_expand "$1")"
  local cfg="$ZAPRET_BASE/config"

  [ -f "$cfg" ] || cp "$ZAPRET_BASE/config.default" "$cfg"
  # Drop any previous managed block, then re-append a fresh one.
  sed -i '/# >>> dpibypass >>>/,/# <<< dpibypass <<</d' "$cfg"
  cat >> "$cfg" <<EOF
# >>> dpibypass >>> (managed by dpi-bypass — do not edit by hand)
FWTYPE=$FWTYPE
MODE_FILTER=none
NFQWS2_ENABLE=1
NFQWS2_PORTS_TCP=$PORTS_TCP
NFQWS2_PORTS_UDP=$PORTS_UDP
NFQWS2_OPT="$opt"
# <<< dpibypass <<<
EOF
}

# Is an nfqws2 daemon currently running?
zap_daemon_up() { pgrep -x nfqws2 >/dev/null 2>&1 || pgrep -f "$NFQWS_BIN" >/dev/null 2>&1; }

# Apply current config now (firewall rules + daemons) via zapret2's own script.
zap_restart() {
  [ -x "$SYSV" ] || die "zapret2 launcher not found at $SYSV — run install first"
  "$SYSV" restart >/dev/null 2>&1 || {
    "$SYSV" stop  >/dev/null 2>&1 || true
    "$SYSV" start >/dev/null 2>&1
  }
  # Give the daemon a moment to either come up or crash on bad options.
  sleep 1
}

zap_stop() {
  [ -x "$SYSV" ] && "$SYSV" stop >/dev/null 2>&1 || true
  if have systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^zapret2\.service'; then
    systemctl stop zapret2 >/dev/null 2>&1 || true
  fi
}

# Make the current strategy survive reboot by installing the systemd unit.
zap_persist() {
  if ! have systemctl; then
    warn "systemd not detected — bypass is active now but won't auto-start on boot."
    return 0
  fi
  install -m 0644 "$UNIT_SRC" /etc/systemd/system/zapret2.service
  systemctl daemon-reload
  systemctl enable zapret2 >/dev/null 2>&1
  systemctl restart zapret2
  ok "Enabled zapret2.service — bypass will start on boot."
}

zap_unpersist() {
  have systemctl || return 0
  systemctl disable --now zapret2 >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/zapret2.service
  systemctl daemon-reload >/dev/null 2>&1 || true
}

# Show the last daemon log lines (why a strategy failed to start).
zap_diag() {
  echo "${C_DIM}--- recent nfqws2 / zapret2 output ---${C_RESET}"
  if have journalctl; then
    journalctl -u zapret2 -n 15 --no-pager 2>/dev/null || true
  fi
  dmesg 2>/dev/null | grep -i nfqws | tail -n 5 || true
}

# Run zapret2's built-in automated strategy discovery.
zap_blockcheck() {
  [ -x "$ZAPRET_BASE/blockcheck2.sh" ] || die "blockcheck2.sh not found — run install first"
  exec "$ZAPRET_BASE/blockcheck2.sh"
}
