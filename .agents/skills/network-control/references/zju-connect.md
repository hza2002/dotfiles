# zju-connect Path

Use this path for SangFor EasyConnect-compatible company VPNs.

## Layout

```text
~/Library/Application Support/via/bin/zju-connect
                                            client binary
~/.config/zju-connect/config.toml        credentials and private domains (0600)
~/.local/var/log/zju-connect.log         lifecycle log (0600)
~/.local/var/run/via-work/               validated zju-connect PID state (0700)
~/.local/bin/via                         work check-update | update | on | off | status
```

Use `../config.example.toml` as the credential-free template. Keep the live configuration out of version control.

## Configure

1. Check the installed binary against the latest upstream Go module release:

```bash
via work check-update
via work update  # run when missing or outdated
```

`via` downloads the latest official `Mythologyli/zju-connect` release for the current Mac architecture, verifies GitHub's SHA-256 digest and the binary version, then replaces the old binary atomically. Do not assume Homebrew manages it unless `brew list --versions zju-connect` proves that on the current machine.

2. Create `~/.config/zju-connect/config.toml` from the example, set mode `0600`, and fill in the gateway, credentials, and private suffixes. Let `via` create its log with mode `0600`.
3. Add a loopback SOCKS5 outbound to the active proxies enhancement selected by `profiles.yaml -> option.proxies`:

```yaml
proxies:
  - name: private-vpn
    type: socks5
    server: 127.0.0.1
    port: 1080
    udp: true
```

4. Prepend explicit private-host rules to the active rules enhancement:

```yaml
prepend:
  - 'DOMAIN,private-service.example.internal,private-vpn'
```

Add a suffix to `custom_proxy_domain` only when zju-connect must always tunnel it and the entire suffix is private. Re-apply the active profile, then start with `via work on`.

## Diagnose

Confirm the process, loopback listeners, live Mihomo rule, and outbound:

```bash
via work status
lsof -nP -iTCP:1080 -iTCP:1081 -sTCP:LISTEN

ROOT="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
SECRET=$(awk '/^secret:/ {print $2; exit}' "$ROOT/clash-verge.yaml")
curl -sS -H "Authorization: Bearer $SECRET" http://127.0.0.1:9097/rules
curl -sS -H "Authorization: Bearer $SECRET" http://127.0.0.1:9097/proxies/private-vpn
```

Compare Clash TUN with the direct SOCKS5 path:

```bash
curl --noproxy '*' -sk -o /dev/null -w "%{http_code} %{time_total}s\n" \
  https://private-service.example.internal/
curl --proxy socks5h://127.0.0.1:1080 -sk -o /dev/null \
  -w "%{http_code} %{time_total}s\n" https://private-service.example.internal/
```

## Retire a Company

1. Record the exact gateway, private suffixes, outbound name, enhancement files, and credential locations without printing secrets. Ask the organization to revoke the account, sessions, device enrollment, client certificate, and TOTP seed where applicable.
2. Run `via work off`. Verify ports `1080` and `1081` have no listeners.
3. Remove the outbound, private rules, and gateway exceptions from persistent enhancements; then re-apply, validate, reload, and inspect the runtime config.
4. Permanently delete the live config and log. Remove shell-history entries only when they expose an organization identifier or secret.
5. Search the Clash root and ZIP backups for the retired gateway, domains, and outbound. Remove only matching organization data.
6. If vendor EasyConnect was installed, use its uninstaller and check applications, package receipts, support files, logs, preferences, LaunchAgents/Daemons, system or kernel extensions, network services/profiles, and vendor certificates.

At minimum, finish with:

```bash
via work status
lsof -nP -iTCP:1080 -iTCP:1081 -sTCP:LISTEN
test ! -e "$HOME/.config/zju-connect/config.toml"
test ! -e "$HOME/.local/var/log/zju-connect.log"

CLASH_ROOT="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
rg -n -F '<retired-gateway-or-domain>' "$CLASH_ROOT"
find "$CLASH_ROOT" -type f -name '*.zip' -exec zipgrep -il '<retired-marker>' {} \;
pkgutil --pkgs | rg -i 'sangfor|easyconnect'
find /Applications /Library "$HOME/Library" -maxdepth 5 \
  \( -iname '*sangfor*' -o -iname '*easyconnect*' \) -print
systemextensionsctl list | rg -i 'sangfor|easyconnect'
kmutil showloaded | rg -i 'sangfor|easyconnect'
```

Classify generic third-party rule-provider matches separately; they are not proof of an installed company VPN. For a full uninstall, retire the company first, then remove zju-connect according to its recorded provenance, empty local directories, the example, and this skill only when none of them remain useful.
