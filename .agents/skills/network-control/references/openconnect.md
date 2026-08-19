# OpenConnect + ocproxy Path

Use this path for Cisco-compatible VPNs implemented without vendor software. The current CUHK(SZ) setup supports only OpenConnect plus ocproxy; do not add a Cisco-client fallback.

## Layout

```text
~/.local/bin/via                         school on | off | status
~/.config/via/school.credentials         username and password (0600)
~/.local/var/log/via-school.log          lifecycle log (0600)
~/.local/var/run/via-school/             OpenConnect and ocproxy PID state (0700)
127.0.0.1:11080                          ocproxy SOCKS5 listener
```

## Configure CUHK(SZ)

1. Install and update `openconnect` and `ocproxy` with Homebrew:

```bash
brew install openconnect ocproxy
```

Use normal Homebrew maintenance to keep both packages current. `via` only manages the VPN lifecycle.

2. Run `via school on`. The first run prompts for the username and password and writes the credentials file. Never print or commit it.
3. Add this outbound to the active proxies enhancement selected by `profiles.yaml -> option.proxies`:

```yaml
proxies:
  - name: school-vpn
    type: socks5
    server: 127.0.0.1
    port: 11080
    udp: false
```

4. Add only verified private hosts to the active rules enhancement. `sis.cuhk.edu.cn` and `myportal.cuhk.edu.cn` use private DNS. CUHK hosts with public DNS and public HTTP responses must remain on normal Clash routing.
5. Keep `vpn.cuhk.edu.cn` and its current public IP direct, exclude the IP from Clash TUN, and put the hostname in `fake-ip-filter`. Re-resolve the IP before assuming the existing exception is current.
6. Re-apply the active profile, validate and reload Mihomo, then test with the school VPN both off and on.

`via` must use the `CUHK(SZ)` auth group and `--no-xmlpost`. OpenConnect runs in native background mode with a PID file and launches `ocproxy` through `--script-tun`.

## Diagnose

Inspect the path from the client outward:

```bash
via school status
lsof -nP -iTCP:11080 -sTCP:LISTEN
tail -n 20 ~/.local/var/log/via-school.log
curl --proxy socks5h://127.0.0.1:11080 -sk -o /dev/null \
  -w "%{http_code} %{time_total}s\n" https://sis.cuhk.edu.cn/
curl --noproxy '*' -sk -o /dev/null -w "%{http_code} %{time_total}s\n" \
  https://sis.cuhk.edu.cn/
```

If startup fails, require a nonzero exit, show the final log entries, stop an unhealthy OpenConnect process, remove a stale ocproxy listener, and then retry. If authentication fails but the web portal works, confirm the auth group and `--no-xmlpost` before changing credentials.

## Retire a School VPN

1. Run `via school off` and verify port `11080` has no listener.
2. Remove `school-vpn`, its private-host rules, and organization gateway exceptions from persistent enhancements. Re-apply, validate, reload, and search the rendered config for school markers.
3. Delete `~/.config/via/school.credentials`, `~/.local/var/log/via-school.log`, and the empty runtime state directory.
4. Remove organization-specific history or backups only when they contain a gateway, username, credential, or private domain.
5. Keep `via`, OpenConnect, ocproxy, and this skill when the reusable toolchain remains useful. Vendor Cisco software is not part of this path.
