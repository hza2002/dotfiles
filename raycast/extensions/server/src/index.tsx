import {
  Action,
  ActionPanel,
  closeMainWindow,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { useRef, useState } from "react";
import { CONFIG_PATH, loadConfig } from "./config";
import { openServer } from "./ghostty";
import {
  checkSshConnection,
  formatSshTarget,
  isLiteralAddress,
  resolvePublicAddresses,
  resolveSshTarget,
  type SshTarget,
} from "./probe";
import type { ServerConfig } from "./types";

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The server could not be opened.";
}

interface PublicAddressResult {
  target: string;
  values: string[];
}

interface ServerProbe {
  target?: SshTarget;
  latency?: number;
  publicAddresses?: PublicAddressResult;
}

export default function Server() {
  const { data, isLoading, error } = useCachedPromise(loadConfig);
  const [probes, setProbes] = useState<Map<string, ServerProbe>>(
    () => new Map(),
  );
  const probeInProgress = useRef(false);

  function updateProbe(
    host: string,
    update: (current: ServerProbe) => ServerProbe,
  ): void {
    setProbes((current) => {
      const next = new Map(current);
      next.set(host, update(next.get(host) ?? {}));
      return next;
    });
  }

  async function resolveTarget(server: ServerConfig): Promise<void> {
    if (probeInProgress.current) return;
    probeInProgress.current = true;
    updateProbe(server.host, () => ({}));
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: `Resolving ${server.title}`,
    });
    try {
      const target = await resolveSshTarget(server.host);
      updateProbe(server.host, () => ({ target }));
      toast.style = Toast.Style.Success;
      toast.title = `${server.title} target resolved`;
      toast.message = formatSshTarget(target);
    } catch (resolveError) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not resolve ${server.title}`;
      toast.message = errorMessage(resolveError);
    } finally {
      probeInProgress.current = false;
    }
  }

  async function resolvePublicIp(
    server: ServerConfig,
    target: SshTarget,
  ): Promise<void> {
    if (probeInProgress.current) return;
    probeInProgress.current = true;
    const targetIdentity = formatSshTarget(target);
    updateProbe(server.host, (current) => ({
      ...current,
      publicAddresses: undefined,
    }));
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: `Resolving ${server.title}`,
    });
    try {
      const addresses = await resolvePublicAddresses(target.hostname);
      updateProbe(server.host, (current) =>
        current.target && formatSshTarget(current.target) === targetIdentity
          ? {
              ...current,
              publicAddresses: { target: targetIdentity, values: addresses },
            }
          : current,
      );
      toast.style = Toast.Style.Success;
      toast.title = `${server.title} public DNS updated`;
      toast.message = addresses.join(", ");
    } catch (resolveError) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not resolve ${server.title}`;
      toast.message = errorMessage(resolveError);
    } finally {
      probeInProgress.current = false;
    }
  }

  async function checkConnection(server: ServerConfig): Promise<void> {
    if (probeInProgress.current) return;
    probeInProgress.current = true;
    updateProbe(server.host, (current) => ({
      ...current,
      latency: undefined,
    }));
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: `Checking ${server.title}`,
    });
    try {
      const latency = await checkSshConnection(server.host);
      updateProbe(server.host, (current) => ({ ...current, latency }));
      toast.style = Toast.Style.Success;
      toast.title = `${server.title} ready in ${latency} ms`;
    } catch (testError) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not connect to ${server.title}`;
      toast.message = errorMessage(testError);
    } finally {
      probeInProgress.current = false;
    }
  }

  async function connect(server: ServerConfig): Promise<void> {
    try {
      await openServer(server);
      await closeMainWindow();
    } catch (connectError) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Could not open ${server.title}`,
        message: errorMessage(connectError),
      });
    }
  }

  if (error && !data) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Warning}
          title="Server configuration unavailable"
          description={errorMessage(error)}
          actions={
            <ActionPanel>
              <Action.Open title="Open Configuration" target={CONFIG_PATH} />
            </ActionPanel>
          }
        />
      </List>
    );
  }

  return (
    <List isLoading={isLoading && !data} searchBarPlaceholder="Filter servers">
      {data?.map((server) => {
        const probe = probes.get(server.host);
        const target = probe?.target;
        const latency = probe?.latency;
        const literalAddress =
          target && isLiteralAddress(target.hostname)
            ? [target.hostname]
            : undefined;
        const targetIdentity = target && formatSshTarget(target);
        const publicAddresses = probe?.publicAddresses;
        const addresses =
          publicAddresses && publicAddresses.target === targetIdentity
            ? publicAddresses.values
            : literalAddress;
        return (
          <List.Item
            key={server.host}
            title={server.title}
            subtitle={
              target
                ? `${server.host} · ${formatSshTarget(target)}`
                : server.host
            }
            icon={Icon.Terminal}
            accessories={[
              ...(addresses?.length
                ? [
                    {
                      text: `${literalAddress ? "IP" : "DNS"}: ${addresses[0]}`,
                      tooltip: addresses.join("\n"),
                    },
                  ]
                : []),
              ...(latency ? [{ text: `${latency} ms` }] : []),
              { text: "tmux main" },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title={`Open ${server.title}`}
                  icon={Icon.Terminal}
                  onAction={() => connect(server)}
                />
                <Action
                  title="Check SSH Connection"
                  icon={Icon.Gauge}
                  onAction={() => checkConnection(server)}
                />
                <Action
                  title={target ? "Refresh SSH Target" : "Resolve SSH Target"}
                  icon={target ? Icon.ArrowClockwise : Icon.Network}
                  onAction={() => resolveTarget(server)}
                />
                {target && !literalAddress ? (
                  <Action
                    title={
                      addresses ? "Refresh Public IP" : "Resolve Public IP"
                    }
                    icon={addresses ? Icon.ArrowClockwise : Icon.Globe}
                    onAction={() => resolvePublicIp(server, target)}
                  />
                ) : null}
                <Action.CopyToClipboard
                  title="Copy SSH Host"
                  content={server.host}
                />
                {target ? (
                  <Action.CopyToClipboard
                    title="Copy SSH Target"
                    content={formatSshTarget(target)}
                  />
                ) : null}
                {addresses ? (
                  <Action.CopyToClipboard
                    title={
                      addresses.length === 1
                        ? "Copy Public IP"
                        : "Copy Public IPs"
                    }
                    content={addresses.join("\n")}
                  />
                ) : null}
                <Action.Open
                  title="Open Server Configuration"
                  target={CONFIG_PATH}
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
