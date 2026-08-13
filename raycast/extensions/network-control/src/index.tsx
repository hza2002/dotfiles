import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  Toast,
  open,
  showToast,
  useNavigation,
} from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { existsSync } from "node:fs";
import { useCallback, useEffect, useRef, useState } from "react";
import { getRouteStatuses, switchRoute, testRouteLatency } from "./mihomo";
import type {
  DashboardData,
  RouteStatus,
  VpnAction,
  VpnId,
  VpnState,
  VpnStatus,
} from "./types";
import { getVpnStatuses, openSetupInGhostty, runVpnAction } from "./vpn";

const VPN_TITLES: Record<VpnId, string> = {
  work: "Work VPN",
  school: "School VPN",
};

const VPN_ORDER: Record<VpnId, number> = {
  school: 0,
  work: 1,
};

const STATE_LABELS: Record<VpnState, string> = {
  connected: "Connected",
  disconnected: "Disconnected",
  unhealthy: "Needs Attention",
  not_configured: "Not Configured",
  disabled: "Disabled",
};

async function loadDashboard(): Promise<DashboardData> {
  const [vpns, routes] = await Promise.all([
    getVpnStatuses(),
    getRouteStatuses(),
  ]);
  return { vpns, routes };
}

function stateColor(state: VpnState): Color {
  switch (state) {
    case "connected":
      return Color.Green;
    case "disconnected":
      return Color.SecondaryText;
    case "unhealthy":
      return Color.Yellow;
    case "not_configured":
      return Color.Orange;
    case "disabled":
      return Color.SecondaryText;
  }
}

function vpnIcon(vpn: VpnStatus): { source: Icon; tintColor: Color } {
  return {
    source: vpn.id === "school" ? Icon.Book : Icon.Building,
    tintColor: stateColor(vpn.state),
  };
}

function routeIcon(route: RouteStatus): { source: Icon; tintColor: Color } {
  if (!route.available)
    return { source: Icon.Warning, tintColor: Color.Yellow };
  return {
    source: route.id === "default" ? Icon.Globe : Icon.Stars,
    tintColor: route.id === "default" ? Color.Blue : Color.Magenta,
  };
}

function vpnSubtitle(vpn: VpnStatus): string {
  if (vpn.issues[0]) return vpn.issues[0].message;
  if (vpn.state === "disabled") return "Disabled in via configuration";
  if (vpn.state === "connected") {
    const elapsed = vpn.processes[0]?.elapsed;
    const listeners = vpn.listeners
      .filter((listener) => listener.owned)
      .map(
        (listener) => `${listener.protocol} ${listener.host}:${listener.port}`,
      )
      .join(" | ");
    return [listeners, elapsed ? `Up ${elapsed}` : undefined]
      .filter(Boolean)
      .join(" | ");
  }
  return vpn.clientVersion ?? "Ready";
}

function primaryVpnAction(state: VpnState): VpnAction | undefined {
  if (state === "connected") return "disconnect";
  if (state === "disconnected") return "connect";
  if (state === "unhealthy") return "reconnect";
  return undefined;
}

function vpnActionTitle(action: VpnAction, title: string): string {
  const verb =
    action === "connect"
      ? "Connect"
      : action === "disconnect"
        ? "Disconnect"
        : "Reconnect";
  return `${verb} ${title}`;
}

function vpnActionIcon(action: VpnAction): Icon {
  if (action === "connect") return Icon.Link;
  if (action === "disconnect") return Icon.XMarkCircle;
  return Icon.ArrowClockwise;
}

function routeSubtitle(route: RouteStatus): string {
  if (!route.available) return route.issue ?? "Routing policy is unavailable.";
  if (!route.selected) return "No route selected";
  if (route.resolved && route.resolved !== route.selected)
    return `${route.selected} -> ${route.resolved}`;
  return route.selected;
}

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The action could not be completed.";
}

function latencyAccessory(route: RouteStatus): { text: string }[] {
  if (!route.available) return [];
  if (!route.delay || !route.testedAt) return [{ text: "Not tested" }];

  const ageMs = Math.max(0, Date.now() - Date.parse(route.testedAt));
  const age =
    ageMs < 60_000
      ? "<1m ago"
      : ageMs < 3_600_000
        ? `${Math.floor(ageMs / 60_000)}m ago`
        : ageMs < 86_400_000
          ? `${Math.floor(ageMs / 3_600_000)}h ago`
          : `${Math.floor(ageMs / 86_400_000)}d ago`;
  return [{ text: `${route.delay} ms · ${age}` }];
}

export default function NetworkControl() {
  const { data, isLoading, revalidate } = usePromise(loadDashboard);
  const [pending, setPending] = useState<Set<string>>(new Set());

  async function refreshStatus() {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Refreshing status",
    });
    try {
      await revalidate();
      toast.style = Toast.Style.Success;
      toast.title = "Status refreshed";
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Refresh failed";
      toast.message = errorMessage(error);
    }
  }

  async function withPending(
    key: string,
    title: string,
    action: () => Promise<void>,
  ) {
    if (pending.has(key)) return;
    setPending((current) => new Set(current).add(key));
    const toast = await showToast({ style: Toast.Style.Animated, title });
    try {
      await action();
      await revalidate();
      toast.style = Toast.Style.Success;
      toast.title = `${title} completed`;
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = `${title} failed`;
      toast.message = errorMessage(error);
    } finally {
      setPending((current) => {
        const next = new Set(current);
        next.delete(key);
        return next;
      });
    }
  }

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Filter routes and connections"
    >
      <List.Section title="Routing">
        {data?.routes.map((route) => {
          return (
            <List.Item
              key={route.id}
              title={route.title}
              subtitle={routeSubtitle(route)}
              icon={routeIcon(route)}
              accessories={latencyAccessory(route)}
              actions={
                <ActionPanel>
                  <ActionPanel.Section>
                    {route.available ? (
                      <Action.Push
                        title={`Select ${route.title} Route`}
                        icon={Icon.Switch}
                        target={
                          <RoutePicker route={route} onChanged={revalidate} />
                        }
                      />
                    ) : (
                      <Action
                        title="Open Clash Verge"
                        icon={Icon.AppWindow}
                        onAction={() => open("/Applications/Clash Verge.app")}
                      />
                    )}
                  </ActionPanel.Section>
                  <ActionPanel.Section>
                    <Action
                      title="Refresh Status"
                      icon={Icon.ArrowClockwise}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                      onAction={refreshStatus}
                    />
                    {route.available ? (
                      <Action
                        title="Open Clash Verge"
                        icon={Icon.AppWindow}
                        onAction={() => open("/Applications/Clash Verge.app")}
                      />
                    ) : null}
                  </ActionPanel.Section>
                </ActionPanel>
              }
            />
          );
        })}
      </List.Section>

      <List.Section title="Connections">
        {data?.vpns
          .toSorted((left, right) => VPN_ORDER[left.id] - VPN_ORDER[right.id])
          .map((vpn) => {
            const title = VPN_TITLES[vpn.id];
            const action = primaryVpnAction(vpn.state);
            const isPending = pending.has(`vpn:${vpn.id}`);
            return (
              <List.Item
                key={vpn.id}
                title={title}
                subtitle={vpnSubtitle(vpn)}
                icon={vpnIcon(vpn)}
                accessories={[
                  { text: isPending ? "Working..." : STATE_LABELS[vpn.state] },
                ]}
                actions={
                  <ActionPanel>
                    <ActionPanel.Section>
                      {action && !isPending ? (
                        <Action
                          title={vpnActionTitle(action, title)}
                          icon={vpnActionIcon(action)}
                          onAction={() =>
                            withPending(
                              `vpn:${vpn.id}`,
                              vpnActionTitle(action, title),
                              async () => {
                                await runVpnAction(vpn.id, action);
                              },
                            )
                          }
                        />
                      ) : null}
                      {vpn.state === "not_configured" && !isPending ? (
                        <Action
                          title="Open Setup in Ghostty"
                          icon={Icon.Terminal}
                          onAction={() =>
                            withPending(
                              `vpn:${vpn.id}`,
                              `Open ${title} setup`,
                              () => openSetupInGhostty(vpn.id),
                            )
                          }
                        />
                      ) : null}
                    </ActionPanel.Section>
                    <ActionPanel.Section>
                      <Action
                        title="Refresh Status"
                        icon={Icon.ArrowClockwise}
                        shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                        onAction={refreshStatus}
                      />
                      {existsSync(vpn.logPath) ? (
                        <Action.Open
                          title="Open Log"
                          icon={Icon.Document}
                          target={vpn.logPath}
                        />
                      ) : null}
                      {vpn.state !== "not_configured" ? (
                        <Action
                          title="Open Setup in Ghostty"
                          icon={Icon.Terminal}
                          onAction={() => openSetupInGhostty(vpn.id)}
                        />
                      ) : null}
                    </ActionPanel.Section>
                  </ActionPanel>
                }
              />
            );
          })}
      </List.Section>
    </List>
  );
}

function RoutePicker({
  route,
  onChanged,
}: {
  route: RouteStatus;
  onChanged: () => Promise<unknown>;
}) {
  const { pop } = useNavigation();
  const [pendingChoice, setPendingChoice] = useState<string>();
  const [latencies, setLatencies] = useState<Record<string, number>>({});
  const [isTesting, setIsTesting] = useState(false);
  const testingRef = useRef(false);
  const mountedRef = useRef(true);

  const runLatencyTest = useCallback(
    async (showFeedback: boolean) => {
      if (testingRef.current) return;
      testingRef.current = true;
      setIsTesting(true);
      const toast = showFeedback
        ? await showToast({
            style: Toast.Style.Animated,
            title: `Testing ${route.title} routes`,
          })
        : undefined;

      try {
        const result = await testRouteLatency(route.group);
        if (mountedRef.current) setLatencies(result);
        if (toast) {
          toast.style = Toast.Style.Success;
          toast.title = `${route.title} latency updated`;
          toast.message = `${Object.keys(result).length} routes tested`;
        }
      } catch (error) {
        if (toast) {
          toast.style = Toast.Style.Failure;
          toast.title = `Could not test ${route.title} routes`;
          toast.message = errorMessage(error);
        }
      } finally {
        testingRef.current = false;
        if (mountedRef.current) setIsTesting(false);
      }
    },
    [route.group, route.title],
  );

  useEffect(() => {
    mountedRef.current = true;
    void runLatencyTest(false);
    return () => {
      mountedRef.current = false;
    };
  }, [runLatencyTest]);

  async function selectRoute(choice: string) {
    if (pendingChoice) return;
    setPendingChoice(choice);
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: `Switching ${route.title} route`,
    });
    try {
      await switchRoute(route.group, choice);
      await onChanged();
      toast.style = Toast.Style.Success;
      toast.title = `${route.title} route updated`;
      pop();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not switch ${route.title} route`;
      toast.message = errorMessage(error);
    } finally {
      setPendingChoice(undefined);
    }
  }

  return (
    <List
      isLoading={pendingChoice !== undefined || isTesting}
      searchBarPlaceholder={`Select ${route.title.toLowerCase()} route`}
    >
      {route.choices.map((choice) => {
        const selected = route.selected === choice.name;
        const subtitle =
          choice.resolved !== choice.name
            ? `Resolves to ${choice.resolved}`
            : undefined;
        return (
          <List.Item
            key={choice.name}
            title={choice.name}
            subtitle={subtitle}
            icon={
              selected
                ? { source: Icon.CheckCircle, tintColor: Color.Green }
                : Icon.Circle
            }
            accessories={
              latencies[choice.name] || choice.delay
                ? [{ text: `${latencies[choice.name] ?? choice.delay} ms` }]
                : []
            }
            actions={
              <ActionPanel>
                <ActionPanel.Section>
                  {!pendingChoice ? (
                    <Action
                      title={selected ? "Keep Selected Route" : "Select Route"}
                      icon={selected ? Icon.CheckCircle : Icon.Switch}
                      onAction={() =>
                        selected ? pop() : selectRoute(choice.name)
                      }
                    />
                  ) : null}
                </ActionPanel.Section>
                <ActionPanel.Section>
                  {!isTesting ? (
                    <Action
                      title="Test Route Latencies"
                      icon={Icon.Gauge}
                      shortcut={{ modifiers: ["cmd"], key: "t" }}
                      onAction={() => runLatencyTest(true)}
                    />
                  ) : null}
                </ActionPanel.Section>
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
