import {
  Action,
  ActionPanel,
  closeMainWindow,
  Detail,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { useCallback, useEffect, useRef, useState } from "react";
import { OVERLAY_PATH } from "./config.ts";
import { describeLocation, formatAddress } from "./geo.ts";
import { openHost } from "./ghostty.ts";
import { loadHosts } from "./hosts.ts";
import { readCachedInfo, refreshInfo } from "./info.ts";
import {
  checkSshConnection,
  formatSshTarget,
  identityFiles,
  nonDefaultOptions,
  readHostKey,
  sshBaseline,
} from "./probe.ts";
import { describeLastConnected, type LastConnectedText } from "./recency.ts";
import { SSH_CONFIG_PATH } from "./sshconfig.ts";
import {
  createServerSpace,
  ensureWindowLanded,
  type ServerSpace,
} from "./space.ts";
import { readStoredConnected, recordConnected } from "./store.ts";
import type { Host, HostInfo } from "./types.ts";

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The host could not be reached.";
}

/** Your own note replaces the target; the detail pane still shows the target. */
function hostSubtitle(host: Host): string {
  if (host.note !== undefined) return host.note;

  const target = formatSshTarget(host.target);
  return host.title === host.alias ? target : `${host.alias} · ${target}`;
}

interface DetailInput {
  host: Host;
  info: HostInfo | undefined;
  latency: number | undefined;
  lastConnected: LastConnectedText;
  baseline: Map<string, string[]> | undefined;
  hostKey: string | null | undefined;
}

/** The detail pane is the only place Raycast renders an aligned table. */
function hostDetail({
  host,
  info,
  latency,
  lastConnected,
  baseline,
  hostKey,
}: DetailInput) {
  const address = info === undefined ? undefined : formatAddress(info);
  const identities = identityFiles(host.sshOptions);
  const options =
    baseline === undefined ? [] : nonDefaultOptions(host.sshOptions, baseline);
  const hostKeyText =
    hostKey === undefined
      ? "Checking…"
      : (hostKey ?? "Not recorded in known_hosts");

  return (
    <List.Item.Detail
      metadata={
        <Detail.Metadata>
          {host.title === host.alias ? null : (
            <Detail.Metadata.Label title="Alias" text={host.alias} />
          )}
          {host.note === undefined ? null : (
            <Detail.Metadata.Label title="Note" text={host.note} />
          )}
          <Detail.Metadata.Label
            title="Target"
            text={formatSshTarget(host.target)}
          />
          <Detail.Metadata.Label
            title="Address"
            text={address ?? "Resolving…"}
          />
          <Detail.Metadata.Label
            title="Location"
            text={info === undefined ? "Resolving…" : describeLocation(info)}
          />
          {identities.length === 0 ? null : (
            <Detail.Metadata.Label
              title="Identity File"
              text={
                identities.length === 1
                  ? identities[0]
                  : `${identities[0]} +${identities.length - 1}`
              }
            />
          )}
          <Detail.Metadata.Label title="Host Key" text={hostKeyText} />
          {options.length === 0 ? (
            <Detail.Metadata.Label
              title="SSH Options"
              text={
                baseline === undefined ? "Checking…" : "Target settings only"
              }
            />
          ) : (
            options.map((option) => (
              <Detail.Metadata.Label
                key={option.key}
                title={option.key}
                text={option.value}
              />
            ))
          )}
          <Detail.Metadata.Label
            title="Last Connected"
            text={lastConnected.description}
          />
          {latency === undefined ? null : (
            <Detail.Metadata.Label title="Latency" text={`${latency} ms`} />
          )}
          <Detail.Metadata.Label title="Tmux Session" text={host.tmuxSession} />
        </Detail.Metadata>
      }
    />
  );
}

export default function Server() {
  const { data, isLoading, error } = usePromise(() =>
    readStoredConnected().then((stored) => loadHosts(stored)),
  );
  const [infos, setInfos] = useState<Map<string, HostInfo>>(() => new Map());
  const [latencies, setLatencies] = useState<Map<string, number>>(
    () => new Map(),
  );
  const [hostKeys, setHostKeys] = useState<Map<string, string | null>>(
    () => new Map(),
  );
  const [baseline, setBaseline] = useState<Map<string, string[]>>();
  const probeInProgress = useRef(false);
  const requested = useRef(new Set<string>());
  const loadedHosts = data?.hosts;
  const overlayError = data?.overlayError;

  useEffect(() => {
    if (overlayError === undefined) return;
    showToast({
      style: Toast.Style.Failure,
      title: "Overlay config ignored",
      message: overlayError,
    });
  }, [overlayError]);

  useEffect(() => {
    let cancelled = false;
    sshBaseline().then((value) => {
      if (!cancelled) setBaseline(value);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  function patchInfo(alias: string, info: HostInfo): void {
    setInfos((current) => new Map(current).set(alias, info));
  }

  function patchHostKey(alias: string, key: string | undefined): void {
    setHostKeys((current) => new Map(current).set(alias, key ?? null));
  }

  /**
   * Addresses, locations, and host keys are looked up for the selected host
   * only, so opening the command costs nothing until a row is highlighted.
   */
  const ensureInfo = useCallback(
    (alias: string | undefined): void => {
      if (alias === undefined || requested.current.has(alias)) return;

      const host = loadedHosts?.find((candidate) => candidate.alias === alias);
      if (host === undefined) return;

      requested.current.add(alias);
      readHostKey(host.target.hostname, host.target.port)
        .then((key) => patchHostKey(alias, key))
        .catch((keyError: unknown) =>
          console.error(
            `Server: host key lookup failed for ${alias}`,
            keyError,
          ),
        );
      refreshInfo([host])
        .then((fresh) => {
          const info = fresh.get(alias);
          if (info !== undefined) patchInfo(alias, info);
        })
        .catch((lookupError: unknown) =>
          console.error(`Server: lookup failed for ${alias}`, lookupError),
        );
    },
    [loadedHosts],
  );

  useEffect(() => {
    if (loadedHosts === undefined || loadedHosts.length === 0) return;

    let cancelled = false;
    readCachedInfo(loadedHosts)
      .then((cached) => {
        if (!cancelled) setInfos(cached);
      })
      .catch((lookupError: unknown) =>
        console.error("Server: cached lookup failed", lookupError),
      );

    // Raycast highlights the first row on open, so its detail needs data too.
    ensureInfo(loadedHosts[0].alias);

    return () => {
      cancelled = true;
    };
  }, [loadedHosts, ensureInfo]);

  function setLatency(alias: string, latency: number | undefined): void {
    setLatencies((current) => {
      const next = new Map(current);
      if (latency === undefined) next.delete(alias);
      else next.set(alias, latency);
      return next;
    });
  }

  async function runProbe(
    host: Host,
    work: () => Promise<string>,
  ): Promise<void> {
    if (probeInProgress.current) return;
    probeInProgress.current = true;
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: `Checking ${host.title}`,
    });
    try {
      const summary = await work();
      toast.style = Toast.Style.Success;
      toast.title = `${host.title}: ${summary}`;
    } catch (probeError) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not reach ${host.title}`;
      toast.message = errorMessage(probeError);
    } finally {
      probeInProgress.current = false;
    }
  }

  function checkConnection(host: Host): Promise<void> {
    return runProbe(host, async () => {
      setLatency(host.alias, undefined);
      const latency = await checkSshConnection(host.alias);
      setLatency(host.alias, latency);
      return `ready in ${latency} ms`;
    });
  }

  function refreshLocation(host: Host): Promise<void> {
    return runProbe(host, async () => {
      const info = (await refreshInfo([host], true)).get(host.alias);
      if (info === undefined) return "no address resolved";

      patchInfo(host.alias, info);
      return formatAddress(info) ?? "no address resolved";
    });
  }

  async function connect(host: Host, newSpace: boolean): Promise<void> {
    let arrival: ServerSpace | undefined;
    if (newSpace) {
      try {
        arrival = await createServerSpace();
      } catch (spaceError) {
        await showToast({
          style: Toast.Style.Failure,
          title: `Opening ${host.title} in the current space`,
          message: errorMessage(spaceError),
        });
      }
    }

    try {
      await openHost(host);
      await recordConnected(host.alias);
      await closeMainWindow();
    } catch (connectError) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Could not open ${host.title}`,
        message: errorMessage(connectError),
      });
      return;
    }

    if (arrival !== undefined) {
      // Raycast is out of the way by now, so a placement miss is worth a log
      // rather than a toast the user cannot act on.
      await ensureWindowLanded(arrival).catch((placeError: unknown) =>
        console.error("Server: could not place the window", placeError),
      );
    }
  }

  return (
    <List
      isShowingDetail
      isLoading={isLoading}
      searchBarPlaceholder="Filter SSH hosts"
      onSelectionChange={ensureInfo}
    >
      {loadedHosts?.length === 0 && !isLoading ? (
        <List.EmptyView
          icon={error ? Icon.Warning : Icon.Terminal}
          title={error ? "SSH hosts unavailable" : "No SSH hosts found"}
          description={
            error
              ? errorMessage(error)
              : `Add a Host block to ${SSH_CONFIG_PATH} and it appears here.`
          }
          actions={
            <ActionPanel>
              <Action.Open title="Open SSH Config" target={SSH_CONFIG_PATH} />
            </ActionPanel>
          }
        />
      ) : null}
      {loadedHosts?.map((host) => {
        const info = infos.get(host.alias);
        const latency = latencies.get(host.alias);
        const lastConnected = describeLastConnected(host.lastConnectedAt);
        return (
          <List.Item
            key={host.alias}
            id={host.alias}
            title={host.title}
            detail={hostDetail({
              host,
              info,
              latency,
              lastConnected,
              baseline,
              hostKey: hostKeys.has(host.alias)
                ? hostKeys.get(host.alias)
                : undefined,
            })}
            subtitle={{
              value: hostSubtitle(host),
              ...(host.note === undefined ? {} : { tooltip: host.note }),
            }}
            icon={Icon.Terminal}
            actions={
              <ActionPanel>
                <Action
                  title={`Open ${host.title}`}
                  icon={Icon.Terminal}
                  onAction={() => connect(host, true)}
                />
                <Action
                  title="Open in Current Space"
                  icon={Icon.Desktop}
                  onAction={() => connect(host, false)}
                />
                <Action
                  title="Check SSH Connection"
                  icon={Icon.Gauge}
                  onAction={() => checkConnection(host)}
                />
                <Action
                  title="Refresh IP and Location"
                  icon={Icon.Globe}
                  onAction={() => refreshLocation(host)}
                />
                <Action.CopyToClipboard
                  title="Copy SSH Target"
                  content={formatSshTarget(host.target)}
                />
                <Action.CopyToClipboard
                  title="Copy SSH Command"
                  content={`ssh ${host.alias}`}
                />
                <Action.Open
                  title="Open SSH Config"
                  target={SSH_CONFIG_PATH}
                  icon={Icon.Gear}
                />
                <Action.Open
                  title="Open Overlay Config"
                  target={OVERLAY_PATH}
                  icon={Icon.Gear}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
