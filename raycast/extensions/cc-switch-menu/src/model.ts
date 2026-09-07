export type MenuNode = {
  title: string;
  identifier: string;
  enabled: boolean;
  checked: boolean;
  children: MenuNode[];
};

export type Entry = {
  key: string;
  group: string;
  route: string[];
  title: string;
  enabled: boolean;
  checked: boolean;
  ambiguous: boolean;
  kind: "selection" | "status";
};

export type Snapshot = { version: 1; capturedAt: number; nodes: MenuNode[] };

export function groupTitle(title: string): string {
  return title.split(" · ")[0];
}

export function isLightweightMode(title: string): boolean {
  return ["Lightweight Mode", "軽量モード", "輕量模式", "轻量模式"].includes(
    title,
  );
}

export function entriesFromMenu(nodes: MenuNode[]): Entry[] {
  const entries: Entry[] = [];
  function walk(items: MenuNode[], route: string[], enabled: boolean) {
    for (const item of items) {
      if (!item.title) continue;
      if (item.children.length) {
        walk(
          item.children,
          [...route, groupTitle(item.title)],
          enabled && item.enabled,
        );
      } else if (route.length) {
        const path = [...route, item.title];
        entries.push({
          key: JSON.stringify(path),
          group: route.join(" / "),
          route: path,
          title: item.title,
          enabled: enabled && item.enabled,
          checked: item.checked,
          ambiguous: false,
          kind: "selection",
        });
      } else if (!item.enabled || isLightweightMode(item.title)) {
        entries.push({
          key: JSON.stringify([item.title]),
          group: groupTitle(item.title),
          route: [item.title],
          title: item.title,
          enabled: item.enabled,
          checked: item.checked,
          ambiguous: false,
          kind: "status",
        });
      }
    }
  }
  walk(nodes, [], true);
  const counts = new Map<string, number>();
  for (const entry of entries)
    counts.set(entry.key, (counts.get(entry.key) ?? 0) + 1);
  return entries.map((entry, index) => ({
    ...entry,
    ambiguous: counts.get(entry.key)! > 1,
    key: `${entry.key}:${index}`,
  }));
}

export function parseSnapshot(value: string | undefined): Snapshot | undefined {
  if (!value) return;
  try {
    const snapshot = JSON.parse(value);
    function valid(node: MenuNode): boolean {
      return (
        typeof node?.title === "string" &&
        typeof node.enabled === "boolean" &&
        typeof node.checked === "boolean" &&
        Array.isArray(node.children) &&
        node.children.every(valid)
      );
    }
    if (
      snapshot.version === 1 &&
      Number.isFinite(snapshot.capturedAt) &&
      Array.isArray(snapshot.nodes) &&
      snapshot.nodes.every(valid)
    )
      return snapshot;
  } catch {
    /* A damaged cache is replaced by a fresh menu read. */
  }
}
