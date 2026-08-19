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
import { CONFIG_PATH, loadConfig } from "./config";
import { openServer } from "./ghostty";
import type { ServerConfig } from "./types";

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The server could not be opened.";
}

export default function Server() {
  const { data, isLoading, error } = useCachedPromise(loadConfig);

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
      {data?.map((server) => (
        <List.Item
          key={server.host}
          title={server.title}
          subtitle={server.host}
          icon={Icon.Terminal}
          accessories={[{ text: "tmux main" }]}
          actions={
            <ActionPanel>
              <Action
                title={`Open ${server.title}`}
                icon={Icon.Terminal}
                onAction={() => connect(server)}
              />
              <Action.CopyToClipboard
                title="Copy SSH Host"
                content={server.host}
              />
              <Action.Open
                title="Open Server Configuration"
                target={CONFIG_PATH}
                icon={Icon.Gear}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
