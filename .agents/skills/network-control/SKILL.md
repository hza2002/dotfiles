---
name: network-control
description: Maintain and troubleshoot the local macOS network-control stack centered on Clash Verge Rev and Mihomo, including active profile state, Mac-only enhancements, via-managed Work and School VPNs, and the Raycast network-control integration. Use for local runtime diagnosis or Mac-specific routing control. Do not use for portable provider aggregation, shared multi-device rules, generated subscriptions, remote-server VPN deployment, or unrelated proxy clients.
---

# Local Network Control

Treat the stack as one system with explicit ownership boundaries:

```text
Raycast network-control  ->  via CLI  ->  Work / School VPN clients
                        ->  Mihomo socket  ->  routing policies

Clash Verge Rev  ->  persistent profile enhancements  ->  Mihomo data plane
```

## Route the Task

Inspect only the surfaces relevant to the request:

- For active Clash state, Mac-only policy enhancements, DNS, provider health, or
  policy selection, discover the selected profile and owning enhancement files
  from the current Clash Verge state. Inspect rendered Mihomo state separately.
- For portable provider inventory, shared policy groups and rules, generated
  Mihomo or Shadowrocket profiles, device enrollment, or subscription
  publication, work from `~/repo/proxy` with `$proxy-config` instead.
- For the Raycast extension, read `raycast/extensions/network-control/README.md`, `package.json`, and the affected source and tests. Treat its installed Raycast copy as generated output.
- For `via`, resolve the installed binary and inspect its current `--help` and versioned JSON status contract. Treat it as an external lifecycle adapter when its source is not present in the repository.
- For EasyConnect-compatible Work VPN changes or failures below `via`, read [references/zju-connect.md](references/zju-connect.md) completely.
- For Cisco-compatible School VPN changes or failures below `via`, read [references/openconnect.md](references/openconnect.md) completely.
- Read both VPN references only when the task crosses both implementations or retires the entire VPN toolchain.

Prefer current source, CLI output, configuration, and runtime state over descriptions in this skill. Do not copy identifiers, provider names, policy names, ports, or process assumptions from an earlier run.

## Preserve the Architecture

- Keep Clash Verge Rev and Mihomo as the data plane. Do not replace Clash TUN with broad system routes.
- Edit the owning persistent source first. Treat `clash-verge.yaml` and the installed Raycast extension as generated state, synchronizing them only for validation or immediate runtime use.
- Resolve active enhancement IDs through the selected profile before editing.
  Local Merge/覆写 remains a Mac consumer layer; do not use it as the source of
  portable providers or shared rules.
- Use `via` as the Work and School VPN lifecycle boundary. Bypass it only when the applicable VPN reference requires lower-level diagnosis or repair.
- Keep VPN clients in user space behind loopback proxies. Do not add vendor roots, setuid binaries, kernel or system extensions, or LaunchDaemons.
- Route only verified private services through VPN outbounds. Keep VPN gateways direct and outside fake-IP or TUN interception.
- Preserve unrelated policy selections, providers, rules, and VPN final state.
- Keep credentials, subscription URLs, controller secrets, and logs out of output and version control. Protect local secret-bearing files with mode `0600`.

Clash Verge Rev keeps its local state under:

```text
$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev
```

## Work From Owner to Consumer

1. Snapshot the relevant source state and runtime state without exposing secrets.
2. Identify the owning component and edit only that source of truth.
3. Validate the owner directly before testing downstream consumers.
4. Re-render or rebuild generated state through its normal lifecycle.
5. Verify the live integration from the user-facing entry point down to the final outbound.
6. Restore the requested VPN and routing state, then remove secret-bearing rollback material.

Use the shortest diagnostic path that isolates ownership:

```text
Raycast action
  -> via status/action or Mihomo socket request
    -> VPN listener or policy group
      -> final outbound and destination
```

If a lower layer works and its consumer fails, repair the consumer contract. If the lower layer fails, diagnose its owner before changing routing around it.

## Validate by Surface

- **Local Clash changes:** validate the rendered configuration with the installed Mihomo binary, reload through the current controller, then confirm live providers, groups, rules, selected policies, and public connectivity.
- **VPN changes:** validate the applicable `via ... status --json` result, process and listener ownership, the direct loopback proxy path, and the same destination through Clash routing.
- **Raycast changes:** run the extension's repository-defined test, lint, and build scripts; verify the built control surface against live `via` and Mihomo interfaces without editing its generated installation directly.
- **Cross-stack changes:** test each boundary independently before testing the complete path. A successful UI action alone is not sufficient evidence.

Do not report success from configuration parsing alone. Confirm the requested behavior in live state and disclose any untested external dependency.

## Retire Owned State

Remove organization-specific or provider-specific state without automatically removing reusable clients, adapters, skills, or UI code. Search persistent and generated state, backups, logs, processes, listeners, services, extensions, certificates, and package receipts as applicable. Finish with negative verification and remove temporary copies containing credentials.
