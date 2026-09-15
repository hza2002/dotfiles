import { Action, ActionPanel, Color, Icon, List } from "@raycast/api";
import { useEffect, useRef, useState } from "react";
import {
  codexView,
  readUsage,
  remainingText,
  resetDetail,
  type PlanView,
} from "./usage";
import { kimiView, readKimiUsage } from "./kimi";

// Each source owns its query and view; failures stay within its section.
const plans = [
  {
    id: "codex",
    title: "Codex",
    query: async () => codexView(await readUsage()),
  },
  {
    id: "kimi",
    title: "Kimi Code",
    query: async () => kimiView(await readKimiUsage()),
  },
];
type Result = { view?: PlanView; error?: string };

// Emphasis follows remaining quota: healthy, low, critical, unknown.
function quotaColor(remaining: number | null): Color {
  if (remaining === null) return Color.SecondaryText;
  if (remaining >= 50) return Color.Green;
  if (remaining >= 20) return Color.Orange;
  return Color.Red;
}

// Reset time uses the inverse scale: the closer the reset, the healthier.
function resetColor(resetsAt: number | null, now: number): Color {
  if (!resetsAt) return Color.SecondaryText;
  const hours = (resetsAt * 1000 - now) / 3_600_000;
  if (hours <= 2) return Color.Green;
  if (hours <= 24) return Color.Orange;
  return Color.Red;
}

export default function Command() {
  const [results, setResults] = useState<Record<string, Result>>({});
  const [busy, setBusy] = useState(true);
  const [now, setNow] = useState(Date.now());
  const request = useRef(0);
  const loading = useRef(false);

  async function refresh() {
    if (loading.current) return;
    loading.current = true;
    const current = ++request.current;
    setBusy(true);
    setResults({});
    await Promise.allSettled(
      plans.map(async (plan) => {
        let result: Result;
        try {
          result = { view: await plan.query() };
        } catch (error) {
          result = {
            error:
              error instanceof Error
                ? error.message
                : "额度查询失败，请刷新重试。",
          };
        }
        if (current === request.current)
          setResults((previous) => ({ ...previous, [plan.id]: result }));
      }),
    );
    if (current === request.current) {
      loading.current = false;
      setBusy(false);
    }
  }

  useEffect(() => {
    void refresh();
    const timer = setInterval(() => setNow(Date.now()), 30000);
    return () => {
      request.current++;
      loading.current = false;
      clearInterval(timer);
    };
  }, []);

  const refreshAction = (
    <ActionPanel>
      <Action
        title="刷新所有额度"
        icon={Icon.ArrowClockwise}
        shortcut={{ modifiers: ["cmd"], key: "r" }}
        onAction={refresh}
      />
    </ActionPanel>
  );

  return (
    <List navigationTitle="Agent Usage" isLoading={busy}>
      {plans.map((plan) => {
        const result = results[plan.id];
        const view = result?.view;
        return (
          <List.Section
            key={plan.id}
            title={
              view
                ? view.title + (view.subtitle ? ` · ${view.subtitle}` : "")
                : plan.title
            }
          >
            {view ? (
              <>
                {view.rows.map((row) => (
                  <List.Item
                    key={row.title}
                    title={row.title}
                    keywords={[plan.title]}
                    icon={{
                      source: Icon.Circle,
                      tintColor: quotaColor(row.remaining),
                    }}
                    accessories={[
                      {
                        text: {
                          value: resetDetail(row, now),
                          color: resetColor(row.resetsAt, now),
                        },
                      },
                      {
                        text: {
                          value: remainingText(row),
                          color: quotaColor(row.remaining),
                        },
                      },
                    ]}
                    actions={refreshAction}
                  />
                ))}
                {view.note && (
                  <List.Item
                    key="reset-credits"
                    title={view.note}
                    keywords={[plan.title]}
                    icon={Icon.Ticket}
                    accessories={
                      view.noteDetail
                        ? [
                            {
                              text: {
                                value: view.noteDetail,
                                color: Color.SecondaryText,
                              },
                            },
                          ]
                        : []
                    }
                    actions={refreshAction}
                  />
                )}
              </>
            ) : (
              <List.Item
                title={result?.error ?? "正在查询…"}
                icon={result?.error ? Icon.ExclamationMark : Icon.Hourglass}
                actions={refreshAction}
              />
            )}
          </List.Section>
        );
      })}
    </List>
  );
}
