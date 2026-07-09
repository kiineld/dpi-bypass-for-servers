# dpi-bypass

One-line DPI-bypass for **Ubuntu node-to-node links**, built on
[bol-van/zapret2](https://github.com/bol-van/zapret2). It installs and builds
zapret2 from source, then gives you a **flowseal-style menu of bypass
strategies** you can try one by one until your VLESS/Reality, Shadowsocks or
Hysteria link punches through the DPI — then locks the winner in as a boot
service.

Inspired by the UX of
[zapret-discord-youtube](https://github.com/flowseal/zapret-discord-youtube),
but for Linux servers and the newer Lua-strategy engine of zapret2.

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB/dpi-bypass/main/install.sh | sudo bash
```

This builds zapret2 from source (needs a compiler; the installer pulls it via
zapret2's `install_prereq.sh`), installs the `dpibypass` command, and drops you
into the menu.

> Replace `YOUR_GITHUB` with your account, or pass your repo explicitly:
> ```bash
> DPIBYPASS_REPO=https://github.com/you/dpi-bypass \
>   bash <(curl -fsSL https://raw.githubusercontent.com/you/dpi-bypass/main/install.sh)
> ```

## Configure

Ports are set in [`config.env`](config.env). Defaults match the request they
were built for:

```sh
PORTS_TCP="443,1443,8443"   # VLESS/Reality + Shadowsocks
PORTS_UDP="443,1443,8443"   # QUIC / Hysteria
TEST_TARGET=""              # optional HOST:PORT of a peer to auto-probe
```

Set `TEST_TARGET` to a peer's port (e.g. `TEST_TARGET="203.0.113.7:443"`) and
`dpibypass test` will auto-check each strategy by connecting to it.

## Use

```bash
dpibypass            # interactive menu
dpibypass test       # cycle strategies until a link works, then persist it
dpibypass blockcheck # zapret2's own automated discovery (exhaustive)
dpibypass list       # show strategies
dpibypass apply 2    # force a specific strategy and persist it
dpibypass status
dpibypass stop | start | restart | logs | uninstall
```

**`test`** walks the presets in [`strategies/`](strategies): for each it writes
`NFQWS2_OPT`, restarts zapret2, verifies the `nfqws2` daemon actually came up
(an unsupported option is reported and skipped, never silently ignored), then
asks whether your link works. Answer `y` and it's persisted via
`zapret2.service`; answer `n` to try the next.

## How it works

- The wrapper **does not reimplement** the packet engine. It drives zapret2's
  own launcher (`/opt/zapret2/init.d/sysv/zapret2`) so `nfqws2` is invoked with
  its Lua libraries and fake blobs exactly as upstream intends.
- A strategy is just an `NFQWS2_OPT` string. Presets are written into a managed
  block at the end of `/opt/zapret2/config`, overriding the defaults.
- Firewall (nftables) NFQUEUE rules and the systemd unit are set up by zapret2.
- `%TCP%` / `%UDP%` in strategy files are replaced with your configured ports.

## Strategies

| # | Name | When to use |
|---|------|-------------|
| 01 | Fake + MultiSplit | Default all-rounder (TCP TLS/SS + QUIC) |
| 02 | Fake + MultiDisorder | DPI that reassembles simple splits |
| 03 | MultiSplit only (no fake) | DPI that detects/drops fake packets |
| 04 | MultiDisorder only (no fake) | Quieter variant of 03 |
| 05 | TLS-only (Reality-safe) | When bypass disrupts your Shadowsocks |
| 06 | QUIC-heavy (Hysteria focus) | When the UDP leg is what's throttled |

Add your own by dropping a `NN-name.strategy` file in `strategies/` — copy an
existing one. If a preset's `nfqws2` options aren't supported by your zapret2
build, `dpibypass test` will flag it as failed and move on; use
`dpibypass blockcheck` to have zapret2 discover a working combination for your
specific DPI.

## Publish to your GitHub

```bash
cd dpi-bypass
git init && git add . && git commit -m "dpi-bypass: zapret2 wrapper"
# edit DPIBYPASS_REPO in install.sh + the URL in this README to your account
git remote add origin git@github.com:YOUR_GITHUB/dpi-bypass.git
git push -u origin main
```

## Notes

- Built for **servers you control**. zapret2 needs `CAP_NET_ADMIN` (runs as
  root) and modifies nftables — expected on a VPN node.
- Strategies drift as DPI changes; if a link degrades later, re-run
  `dpibypass test` or `dpibypass blockcheck`.
- Uninstall with `dpibypass uninstall` (removes the service and firewall rules;
  optionally deletes the zapret2 source).
