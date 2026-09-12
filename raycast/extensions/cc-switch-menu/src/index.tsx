import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  LocalStorage,
  Toast,
  environment,
  open,
  showToast,
} from "@raycast/api";
import { useCachedState } from "@raycast/utils";
import { useEffect, useRef, useState } from "react";
import { readMenu } from "./backend";
import {
  entriesFromMenu,
  isLightweightMode,
  parseSnapshot,
  providerDisplayTitle,
} from "./model";
import type { Entry, Snapshot } from "./model";
import {
  officialProviders,
  readUsage,
  formatLocalTime,
  usageMarkdown,
} from "./usage";
import type { Usage } from "./usage";

const CACHE_KEY = "menu-snapshot-v1";

function quotaColor(remaining: number): Color {
  if (remaining <= 10) return Color.Red;
  if (remaining <= 30) return Color.Orange;
  return Color.Green;
}

export default function Command() {
  const [snapshot, setSnapshot] = useState<Snapshot>();
  const [filter, setFilter] = useCachedState("app-filter", "all");
  const [busy, setBusy] = useState(true);
  const [pending, setPending] = useState<string>();
  const [failure, setFailure] = useState<string>();
  const lock = useRef(false);
  const [usageByName, setUsageByName] = useState<
    Record<string, { data?: Usage; error?: string }>
  >({});
  const [usageBusy, setUsageBusy] = useState(false);
  const [now, setNow] = useState(Date.now());
  const usageRequest = useRef(0);
  const entries = snapshot ? entriesFromMenu(snapshot.nodes) : [];
  const globalGroups = entries
    .filter(
      (entry) => entry.kind === "status" && isLightweightMode(entry.title),
    )
    .map((entry) => entry.group);
  const groups = [...new Set(entries.map((entry) => entry.group))].filter(
    (group) => !globalGroups.includes(group),
  );
  const activeFilter = groups.includes(filter) ? filter : "all";
  async function updateUsage() {
    const request = ++usageRequest.current;
    setUsageBusy(true);
    setUsageByName({});
    try {
      const providers = (await officialProviders()).filter((provider) =>
        entries.some(
          (entry) =>
            entry.group === "Codex" &&
            entry.route.length === 2 &&
            entry.title === provider.name &&
            !entry.ambiguous,
        ),
      );
      const next: typeof usageByName = Object.fromEntries(
        providers.map((provider) => [provider.name, {}]),
      );
      if (request !== usageRequest.current) return;
      setUsageByName({ ...next });
      for (const provider of providers) {
        try {
          next[provider.name] = { data: await readUsage(provider) };
        } catch (error) {
          next[provider.name] = {
            error: error instanceof Error ? error.message : "额度查询失败",
          };
        }
        if (request !== usageRequest.current) return;
        setUsageByName({ ...next });
      }
    } catch {
      if (request === usageRequest.current)
        await showToast({
          style: Toast.Style.Failure,
          title: "无法识别官方 provider",
          message: "请确认 CC Switch 数据库可读取，再刷新额度。",
        });
    } finally {
      if (request === usageRequest.current) setUsageBusy(false);
    }
  }

  useEffect(() => {
    if (snapshot && entries.some((entry) => entry.group === "Codex")) {
      void updateUsage();
    } else {
      setUsageByName({});
      setUsageBusy(false);
    }
    return () => {
      usageRequest.current++;
    };
  }, [snapshot]);

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 30000);
    return () => clearInterval(timer);
  }, []);
  async function update(entry?: Entry) {
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setPending(entry?.key);
    let toast: Toast | undefined;
    try {
      toast = await showToast({
        style: Toast.Style.Animated,
        title: entry
          ? `正在切换 ${providerDisplayTitle(entry.title)}`
          : "正在读取 CC Switch 菜单",
      });
      const next = await readMenu(environment.assetsPath, entry);
      setSnapshot(next);
      setFailure(undefined);
      await LocalStorage.setItem(CACHE_KEY, JSON.stringify(next));
      toast.style = Toast.Style.Success;
      toast.title = entry
        ? `已确认选中 ${providerDisplayTitle(entry.title)}`
        : "菜单已刷新";
    } catch (error) {
      const message = error instanceof Error ? error.message : "操作失败";
      setFailure(message);
      if (toast) {
        toast.style = Toast.Style.Failure;
        toast.title = entry ? "切换未完成" : "菜单读取失败";
        toast.message = message;
      }
    } finally {
      lock.current = false;
      setBusy(false);
      setPending(undefined);
    }
  }

  useEffect(() => {
    void (async () => {
      const cached = parseSnapshot(
        await LocalStorage.getItem<string>(CACHE_KEY).catch(() => undefined),
      );
      if (cached) {
        setSnapshot(cached);
        setBusy(false);
      } else {
        await update();
      }
    })();
  }, []);

  function commonActions() {
    return (
      <ActionPanel.Section>
        <Action
          title="刷新 OpenAI 额度"
          icon={Icon.ArrowClockwise}
          shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
          onAction={() => {
            if (!usageBusy) void updateUsage();
          }}
        />
        <Action
          title="刷新菜单"
          icon={Icon.ArrowClockwise}
          shortcut={{ modifiers: ["cmd"], key: "r" }}
          onAction={() => update()}
        />
        <Action
          title="打开 CC Switch"
          icon={Icon.AppWindow}
          shortcut={{ modifiers: ["cmd"], key: "o" }}
          onAction={() => open("/Applications/CC Switch.app")}
        />
      </ActionPanel.Section>
    );
  }

  return (
    <List
      isLoading={busy || usageBusy}
      isShowingDetail={entries.length > 0}
      navigationTitle="CC Switch"
      searchBarPlaceholder="搜索菜单选项"
      searchBarAccessory={
        <List.Dropdown
          tooltip="菜单分组"
          value={activeFilter}
          onChange={setFilter}
        >
          <List.Dropdown.Item title="全部分组" value="all" />
          {groups.map((group) => (
            <List.Dropdown.Item key={group} title={group} value={group} />
          ))}
        </List.Dropdown>
      }
    >
      <List.EmptyView
        icon={failure ? Icon.ExclamationMark : Icon.AppWindow}
        title={failure ? "无法读取菜单" : "没有菜单选项"}
        description={failure}
        actions={<ActionPanel>{commonActions()}</ActionPanel>}
      />
      {[
        ...groups.filter(
          (group) => activeFilter === "all" || activeFilter === group,
        ),
        ...new Set(globalGroups),
      ].map((group) => (
        <List.Section
          key={group}
          title={globalGroups.includes(group) ? "全局" : group}
          subtitle={`${entries.filter((entry) => entry.group === group).length}`}
        >
          {entries
            .filter((entry) => entry.group === group)
            .map((entry) => {
              const displayTitle = providerDisplayTitle(entry.title);
              const quota =
                entry.group === "Codex" &&
                entry.route.length === 2 &&
                !entry.ambiguous
                  ? usageByName[entry.title]
                  : undefined;
              const blocked = !entry.enabled || entry.ambiguous;
              const status =
                pending === entry.key
                  ? "切换中"
                  : entry.kind === "status" && entry.enabled
                    ? entry.checked
                      ? "已开启"
                      : "已关闭"
                    : entry.ambiguous
                      ? "同名冲突"
                      : !entry.enabled
                        ? "不可用"
                        : entry.checked
                          ? "使用中"
                          : "";
              const quotaAccessories = quota?.data
                ? [
                    ...(quota.data.fiveHour
                      ? [
                          {
                            text: {
                              value: `5h ${100 - quota.data.fiveHour.usedPercent}%`,
                              color: quotaColor(
                                100 - quota.data.fiveHour.usedPercent,
                              ),
                            },
                          },
                        ]
                      : []),
                    ...(quota.data.weekly
                      ? [
                          {
                            text: {
                              value: `7d ${100 - quota.data.weekly.usedPercent}%`,
                              color: quotaColor(
                                100 - quota.data.weekly.usedPercent,
                              ),
                            },
                          },
                        ]
                      : []),
                    ...(quota.data.resetCredits !== undefined
                      ? [
                          {
                            text: `R${quota.data.resetCredits}`,
                            tooltip: `可用重置次数：${quota.data.resetCredits}`,
                          },
                        ]
                      : []),
                  ]
                : [];
              return (
                <List.Item
                  key={entry.key}
                  id={entry.key}
                  title={displayTitle}
                  keywords={[entry.group, entry.title]}
                  icon={{
                    source: entry.checked
                      ? Icon.CheckCircle
                      : blocked
                        ? Icon.MinusCircle
                        : Icon.Circle,
                    tintColor: entry.checked
                      ? Color.Green
                      : Color.SecondaryText,
                  }}
                  accessories={[
                    ...quotaAccessories,
                    ...(quota?.data || !status ? [] : [{ text: status }]),
                  ]}
                  detail={
                    <List.Item.Detail
                      markdown={
                        quota
                          ? usageMarkdown(quota.data, quota.error, now)
                          : undefined
                      }
                      metadata={
                        quota ? undefined : (
                          <List.Item.Detail.Metadata>
                            <List.Item.Detail.Metadata.Label
                              title="菜单分组"
                              text={entry.group}
                            />
                            <List.Item.Detail.Metadata.Label
                              title="选项"
                              text={displayTitle}
                            />
                            <List.Item.Detail.Metadata.Label
                              title="菜单状态"
                              text={
                                entry.kind === "status" && entry.enabled
                                  ? entry.checked
                                    ? "已开启"
                                    : "已关闭"
                                  : entry.checked
                                    ? "已选中"
                                    : blocked
                                      ? "不可用"
                                      : "可选择"
                              }
                            />
                            <List.Item.Detail.Metadata.Separator />
                            <List.Item.Detail.Metadata.Label
                              title="菜单快照"
                              text={
                                snapshot
                                  ? formatLocalTime(snapshot.capturedAt)
                                  : ""
                              }
                            />
                            {failure && (
                              <List.Item.Detail.Metadata.Label
                                title="最近操作"
                                text={failure}
                              />
                            )}
                          </List.Item.Detail.Metadata>
                        )
                      }
                    />
                  }
                  actions={
                    <ActionPanel>
                      {!blocked && entry.kind === "selection" && (
                        <Action
                          title={entry.checked ? "刷新当前选择" : "选择此项"}
                          icon={
                            entry.checked ? Icon.CheckCircle : Icon.ArrowRight
                          }
                          onAction={() =>
                            update(entry.checked ? undefined : entry)
                          }
                        />
                      )}
                      {commonActions()}
                    </ActionPanel>
                  }
                />
              );
            })}
        </List.Section>
      ))}
    </List>
  );
}
