import { loadOverlay } from "./config.ts";
import { resolveSshTarget, type ResolvedSshHost } from "./probe.ts";
import { lastConnectedFromHistory, readHistory } from "./recency.ts";
import { loadSshHosts, type SshHostEntry } from "./sshconfig.ts";
import type { Host, KnownHost, Overlay } from "./types.ts";

export const DEFAULT_TMUX_SESSION = "main";

export interface HostsResult {
  hosts: Host[];
  overlayError?: string;
}

export function buildHosts(
  entries: SshHostEntry[],
  resolved: Map<string, ResolvedSshHost>,
  lastConnected: Map<string, number>,
  overlay: Overlay,
): Host[] {
  const excluded = new Set(overlay.exclude);
  const included = new Set(overlay.include);
  const observed = new Set<string>();
  const hosts: Host[] = [];

  for (const entry of entries) {
    const alias = entry.alias;
    if (excluded.has(alias)) continue;

    const resolvedHost = resolved.get(alias);
    if (resolvedHost === undefined) continue;

    const { target, options } = resolvedHost;

    // Git-only hosts exist for `git push`, not for opening a shell.
    if (target.user === "git" && !included.has(alias)) continue;

    const identity = `${target.user}@${target.hostname}:${target.port}`;
    if (observed.has(identity)) continue;
    observed.add(identity);

    const override = overlay.hosts[alias];
    hosts.push({
      alias,
      title: override?.title ?? alias,
      ...(entry.note === undefined ? {} : { note: entry.note }),
      target,
      sshOptions: options,
      tmuxSession: override?.tmuxSession ?? DEFAULT_TMUX_SESSION,
      lastConnectedAt: lastConnected.get(alias),
    });
  }

  // Stable sort, so hosts that were never used keep their configuration order.
  return hosts.sort(
    (left, right) => (right.lastConnectedAt ?? 0) - (left.lastConnectedAt ?? 0),
  );
}

async function resolveTargets(
  aliases: string[],
): Promise<Map<string, ResolvedSshHost>> {
  const resolved: [string, ResolvedSshHost][] = [];
  await Promise.all(
    aliases.map(async (alias) => {
      try {
        resolved.push([alias, await resolveSshTarget(alias)]);
      } catch (error) {
        console.error(`Failed to resolve ${alias}:`, error);
      }
    }),
  );
  return new Map(resolved);
}

export async function loadHosts(
  storedConnected: Map<string, number> = new Map(),
): Promise<HostsResult> {
  const [entries, overlayResult] = await Promise.all([
    loadSshHosts(),
    loadOverlay(),
  ]);
  const resolved = await resolveTargets(entries.map((entry) => entry.alias));

  const known: KnownHost[] = [...resolved].map(([alias, host]) => ({
    alias,
    hostname: host.target.hostname,
  }));
  const lastConnected = lastConnectedFromHistory(await readHistory(), known);
  for (const [alias, at] of storedConnected) {
    lastConnected.set(alias, Math.max(lastConnected.get(alias) ?? 0, at));
  }

  const hosts = buildHosts(
    entries,
    resolved,
    lastConnected,
    overlayResult.overlay,
  );
  return overlayResult.error === undefined
    ? { hosts }
    : { hosts, overlayError: overlayResult.error };
}
