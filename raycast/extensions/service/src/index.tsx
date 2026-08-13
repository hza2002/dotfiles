import {
  Action,
  ActionPanel,
  Color,
  Icon,
  Keyboard,
  List,
  Toast,
  open,
  showToast,
} from "@raycast/api";
import { useCachedPromise } from "@raycast/utils";
import { useRef, useState } from "react";
import { expandHome, runServiceAction } from "./actions";
import { CONFIG_PATH, loadConfig } from "./config";
import {
  checkServices,
  waitUntilHealthy,
  waitUntilUnavailable,
} from "./health";
import { STOP_SHORTCUT } from "./shortcuts";
import {
  canRestartService,
  canStartService,
  canStopService,
} from "./service-actions";
import type {
  ServiceAction,
  ServiceConfig,
  ServiceIcon,
  ServiceState,
  ServiceStatus,
} from "./types";

const STATE_LABELS: Record<ServiceState, string> = {
  running: "Running",
  unavailable: "Unavailable",
  error: "HTTP Error",
  unknown: "Unknown",
};

const SERVICE_ICONS: Record<ServiceIcon, Icon> = {
  blog: Icon.Book,
  terminal: Icon.Terminal,
  document: Icon.Document,
  dashboard: Icon.Gauge,
};

async function loadDashboard(): Promise<ServiceStatus[]> {
  return checkServices(await loadConfig());
}

function stateColor(state: ServiceState): Color {
  switch (state) {
    case "running":
      return Color.Green;
    case "unavailable":
      return Color.SecondaryText;
    case "error":
      return Color.Red;
    case "unknown":
      return Color.Yellow;
  }
}

function subtitle(status: ServiceStatus): string {
  if (status.message) return status.message;
  try {
    const url = new URL(status.service.url);
    return `${url.host}${url.pathname === "/" ? "" : url.pathname}`;
  } catch {
    return status.service.url;
  }
}

function accessories(
  status: ServiceStatus,
  pendingOperation?: string,
): List.Item.Accessory[] {
  if (pendingOperation) return [{ text: pendingOperation }];
  const items: List.Item.Accessory[] = [];
  if (status.latencyMs !== undefined)
    items.push({ text: `${status.latencyMs} ms` });
  items.push({
    text: STATE_LABELS[status.state],
    icon: { source: Icon.CircleFilled, tintColor: stateColor(status.state) },
  });
  return items;
}

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The action could not be completed.";
}

export default function Service() {
  const { data, isLoading, error, revalidate } =
    useCachedPromise(loadDashboard);
  const [pending, setPending] = useState<Record<string, string>>({});
  const activeServices = useRef<Set<string>>(new Set());

  async function refreshStatus(showFeedback = true): Promise<void> {
    const toast = showFeedback
      ? await showToast({
          style: Toast.Style.Animated,
          title: "Refreshing services",
        })
      : undefined;
    try {
      await revalidate();
      if (toast) {
        toast.style = Toast.Style.Success;
        toast.title = "Services refreshed";
      }
    } catch (refreshError) {
      if (toast) {
        toast.style = Toast.Style.Failure;
        toast.title = "Refresh failed";
        toast.message = errorMessage(refreshError);
      }
    }
  }

  async function manage(
    service: ServiceConfig,
    operation: "start" | "stop" | "restart",
    action?: ServiceAction,
  ): Promise<void> {
    if (activeServices.current.has(service.id)) return;
    activeServices.current.add(service.id);
    const presentParticiple =
      operation === "start"
        ? "Starting"
        : operation === "stop"
          ? "Stopping"
          : "Restarting";
    setPending((current) => ({
      ...current,
      [service.id]: `${presentParticiple}...`,
    }));
    let toast: Toast | undefined;
    try {
      toast = await showToast({
        style: Toast.Style.Animated,
        title: `${presentParticiple} ${service.title}`,
      });
      if (operation === "restart" && !action && service.stop && service.start) {
        await runServiceAction(service.stop, "stop");
        await waitUntilUnavailable(service);
        await runServiceAction(service.start, "start");
      } else if (action) {
        await runServiceAction(action, operation);
      } else {
        throw new Error(`${service.title} does not support ${operation}.`);
      }
      if (operation === "stop") {
        setPending((current) => ({
          ...current,
          [service.id]: "Waiting to stop...",
        }));
        await waitUntilUnavailable(service);
      } else {
        setPending((current) => ({
          ...current,
          [service.id]: "Waiting for health...",
        }));
        await waitUntilHealthy(service);
      }
      await revalidate();
      if (operation === "start") await open(service.url);
      toast.style = Toast.Style.Success;
      toast.title = `${service.title} ${operation === "stop" ? "stopped" : "is running"}`;
    } catch (actionError) {
      if (toast) {
        toast.style = Toast.Style.Failure;
        toast.title = `Could not ${operation} ${service.title}`;
        toast.message = errorMessage(actionError);
      }
      await revalidate();
    } finally {
      activeServices.current.delete(service.id);
      setPending((current) => {
        const next = { ...current };
        delete next[service.id];
        return next;
      });
    }
  }

  if (error && !data) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Warning}
          title="Service configuration unavailable"
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

  function renderItem(status: ServiceStatus) {
    const service = status.service;
    const isPending = pending[service.id] !== undefined;
    const canStart = canStartService(service, status.state);
    const canRestart =
      service.restart ?? (service.start && service.stop ? undefined : false);
    return (
      <List.Item
        key={service.id}
        title={service.title}
        subtitle={subtitle(status)}
        icon={{
          source: SERVICE_ICONS[service.icon],
          tintColor: stateColor(status.state),
        }}
        accessories={accessories(status, pending[service.id])}
        actions={
          <ActionPanel>
            <ActionPanel.Section>
              {status.state === "running" || status.state === "error" ? (
                <Action.OpenInBrowser
                  title={`Open ${service.title}`}
                  url={service.url}
                />
              ) : canStart && !isPending ? (
                <Action
                  title={`Start ${service.title}`}
                  icon={Icon.Play}
                  onAction={() => manage(service, "start", service.start)}
                />
              ) : !isPending ? (
                <Action
                  title={`Check ${service.title}`}
                  icon={Icon.ArrowClockwise}
                  onAction={() => refreshStatus(false)}
                />
              ) : null}
            </ActionPanel.Section>
            <ActionPanel.Section>
              <Action
                title="Refresh All Services"
                icon={Icon.ArrowClockwise}
                shortcut={{ modifiers: ["cmd", "opt"], key: "r" }}
                onAction={() => refreshStatus()}
              />
              {canRestartService(service, status.state) && !isPending ? (
                <Action
                  title={`Restart ${service.title}`}
                  icon={Icon.RotateClockwise}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                  onAction={() =>
                    manage(service, "restart", canRestart || undefined)
                  }
                />
              ) : null}
              {canStopService(service, status.state) && !isPending ? (
                <Action
                  title={`Stop ${service.title}`}
                  icon={Icon.Stop}
                  shortcut={STOP_SHORTCUT}
                  onAction={() => manage(service, "stop", service.stop)}
                />
              ) : null}
            </ActionPanel.Section>
            <ActionPanel.Section>
              <Action.OpenInBrowser
                title="Open URL Regardless of Status"
                url={service.url}
                shortcut={Keyboard.Shortcut.Common.Open}
              />
              <Action.CopyToClipboard
                title="Copy URL"
                content={service.url}
                shortcut={{ modifiers: ["cmd"], key: "c" }}
              />
              {service.projectPath ? (
                <Action.Open
                  title="Open Project"
                  target={expandHome(service.projectPath)}
                  icon={Icon.Folder}
                />
              ) : null}
              {service.logPath ? (
                <Action.Open
                  title="Open Log"
                  target={expandHome(service.logPath)}
                  icon={Icon.Document}
                />
              ) : null}
              <Action.Open
                title="Open Service Configuration"
                target={CONFIG_PATH}
                icon={Icon.Gear}
              />
            </ActionPanel.Section>
          </ActionPanel>
        }
      />
    );
  }

  const local =
    data?.filter((status) => status.service.group === "local") ?? [];
  const remote =
    data?.filter((status) => status.service.group === "remote") ?? [];

  return (
    <List
      isLoading={isLoading && !data}
      searchBarPlaceholder="Filter personal services"
    >
      <List.Section title="Local">{local.map(renderItem)}</List.Section>
      <List.Section title="Remote">{remote.map(renderItem)}</List.Section>
    </List>
  );
}
