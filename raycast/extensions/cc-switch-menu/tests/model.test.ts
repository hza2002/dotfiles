import { test } from "node:test";
import assert from "node:assert/strict";
import { entriesFromMenu, parseSnapshot } from "../src/model.ts";
import type { MenuNode } from "../src/model.ts";

const node = (
  title: string,
  children: MenuNode[] = [],
  overrides = {},
): MenuNode => ({
  title,
  children,
  identifier: "",
  enabled: true,
  checked: false,
  ...overrides,
});

test("discovers unknown apps, nesting, order, marks and disabled states", () => {
  const entries = entriesFromMenu([
    node("Open"),
    node("New App · First", [
      node("First", [], { checked: true }),
      node("Second", [], { enabled: false }),
    ]),
    node("Profiles", [node("Future", [node("Team")])]),
    node("Empty (no providers)", [], { enabled: false }),
  ]);
  assert.deepEqual(
    entries.map((entry) => [
      entry.group,
      entry.title,
      entry.checked,
      entry.enabled,
    ]),
    [
      ["New App", "First", true, true],
      ["New App", "Second", false, false],
      ["Profiles / Future", "Team", false, true],
      ["Empty (no providers)", "Empty (no providers)", false, false],
    ],
  );
});

test("duplicate routes are blocked, duplicate names across apps are allowed", () => {
  const entries = entriesFromMenu([
    node("A", [node("Same"), node("Same")]),
    node("B", [node("Same")]),
  ]);
  assert.deepEqual(
    entries.map((entry) => entry.ambiguous),
    [true, true, false],
  );
});

test("global mode is read-only and nested profiles retain their group", () => {
  for (const checked of [true, false]) {
    const entries = entriesFromMenu([
      node("Projects", [node("Codex", [node("Team", [], { checked: true })])]),
      node("Lightweight Mode", [], { checked }),
      node("Quit"),
    ]);
    assert.equal(entries.length, 2);
    assert.equal(entries[0].group, "Projects / Codex");
    assert.equal(entries[0].kind, "selection");
    assert.equal(entries[1].kind, "status");
    assert.equal(entries[1].checked, checked);
  }
});

test("corrupt or outdated snapshots are discarded", () => {
  for (const value of [
    undefined,
    "bad",
    "{}",
    '{"version":1,"capturedAt":1,"nodes":[{}]}',
  ])
    assert.equal(parseSnapshot(value), undefined);
  assert.ok(
    parseSnapshot(
      JSON.stringify({ version: 1, capturedAt: 1, nodes: [node("A")] }),
    ),
  );
});
