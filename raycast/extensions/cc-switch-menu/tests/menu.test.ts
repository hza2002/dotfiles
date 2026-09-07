import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const source = readFileSync(
  new URL("../assets/menu.js", import.meta.url),
  "utf8",
);
type Item = {
  title: string;
  checked?: boolean;
  enabled?: boolean;
  children?: Item[];
};

function fixture(
  items: Item[],
  acceptClick = true,
  completionTicks = 1,
  hideDuringRebuild = false,
) {
  let clicks = 0;
  let dismissed = 0;
  let ticks = 0;
  let pending: (() => void) | undefined;
  let visible = true;
  function menu(children: Item[], parent?: Item): unknown {
    return {
      menuItems: () =>
        children.map((item) => {
          const submenus = () =>
            item.children ? [menu(item.children, item)] : [];
          Object.defineProperty(submenus, "length", {
            value: item.children ? 1 : 0,
          });
          if (item.children)
            Object.assign(submenus, { 0: menu(item.children, item) });
          return {
            menus: submenus,
            attributes: {
              byName: (name: string) => ({
                value: () =>
                  ({
                    AXTitle: item.title,
                    AXEnabled: item.enabled !== false,
                    AXMenuItemMarkChar: item.checked ? "check" : "",
                    AXIdentifier: "",
                  })[name as "AXTitle"],
              }),
            },
            click: () => {
              clicks++;
              item.checked = !item.checked;
              if (acceptClick) {
                pending = () => {
                  for (const sibling of children) sibling.checked = false;
                  item.checked = true;
                  if (parent && parent.title.includes(" · "))
                    parent.title = `${parent.title.split(" · ")[0]} · ${item.title}`;
                };
              }
            },
          };
        }),
    };
  }
  const tray = {
    click: () => {},
    get menus() {
      return visible ? [menu(items)] : [];
    },
  };
  const se = {
    keyCode: () => dismissed++,
    processes: {
      byName: () => ({
        exists: () => true,
        menuBars: [{}, { menuBarItems: [tray] }],
      }),
    },
  };
  const context = vm.createContext({
    Application: () => se,
    delay: () => {
      if (!clicks) return;
      ticks++;
      visible = !(hideDuringRebuild && ticks < completionTicks);
      if (pending && ticks >= completionTicks) {
        pending();
        pending = undefined;
      }
    },
  });
  vm.runInContext(source, context);
  return {
    run: (route?: string[]) =>
      context.run(route ? [JSON.stringify(route)] : []),
    clicks: () => clicks,
    dismissed: () => dismissed,
    ticks: () => ticks,
  };
}

test("switches through freshly resolved route and verifies the mark", () => {
  const f = fixture([
    {
      title: "Future · Old",
      children: [{ title: "Old", checked: true }, { title: "New" }],
    },
  ]);
  const snapshot = JSON.parse(f.run(["Future", "New"]));
  assert.equal(f.clicks(), 1);
  assert.equal(snapshot[0].children[1].checked, true);
  assert.equal(f.dismissed(), 1);
});

test("current selection does not invoke switching again", () => {
  const f = fixture([
    {
      title: "Future · Current",
      children: [{ title: "Current", checked: true }],
    },
  ]);
  f.run(["Future", "Current"]);
  assert.equal(f.clicks(), 0);
});

test("renamed, duplicate and disabled targets fail without clicking", () => {
  for (const children of [
    [{ title: "Renamed" }],
    [{ title: "Target" }, { title: "Target" }],
    [{ title: "Target", enabled: false }],
  ]) {
    const f = fixture([{ title: "App", children }]);
    assert.throws(() => f.run(["App", "Target"]));
    assert.equal(f.clicks(), 0);
    assert.equal(f.dismissed(), 1);
  }
});

test("does not report success if the native app does not select the target", () => {
  const f = fixture([{ title: "App", children: [{ title: "Target" }] }], false);
  assert.throws(() => f.run(["App", "Target"]), /verify/);
});

test("native immediate check does not confirm a failed provider switch", () => {
  const f = fixture(
    [
      {
        title: "Codex · Old",
        children: [{ title: "Old", checked: true }, { title: "New" }],
      },
    ],
    false,
  );
  assert.throws(() => f.run(["Codex", "New"]), /verify/);
  assert.equal(f.clicks(), 1);
  assert.equal(f.dismissed(), 1);
});

test("waits for async completion and survives a temporarily absent menu", () => {
  for (const hidden of [false, true]) {
    const f = fixture(
      [
        {
          title: "Codex · Old",
          children: [{ title: "Old", checked: true }, { title: "New" }],
        },
      ],
      true,
      6,
      hidden,
    );
    const snapshot = JSON.parse(f.run(["Codex", "New"]));
    assert.equal(snapshot[0].title, "Codex · New");
    assert.deepEqual(
      snapshot[0].children.map((item: Item) => item.checked),
      [false, true],
    );
    assert.equal(f.clicks(), 1);
    assert.ok(f.ticks() >= 6);
  }
});

test("already marked but inconsistent selections are not accepted or clicked", () => {
  for (const children of [
    [
      { title: "Old", checked: true },
      { title: "New", checked: true },
    ],
    [{ title: "Old" }, { title: "New", checked: true }],
  ]) {
    const f = fixture([{ title: "Codex · Old", children }]);
    assert.throws(() => f.run(["Codex", "New"]), /verify/);
    assert.equal(f.clicks(), 0);
  }
});

test("nested profile selections confirm without a provider title suffix", () => {
  const f = fixture(
    [
      {
        title: "Projects",
        children: [
          {
            title: "Codex",
            children: [{ title: "None", checked: true }, { title: "Work" }],
          },
        ],
      },
    ],
    true,
    4,
  );
  const snapshot = JSON.parse(f.run(["Projects", "Codex", "Work"]));
  assert.deepEqual(
    snapshot[0].children[0].children.map((item: Item) => item.checked),
    [false, true],
  );
});

test("cannot invoke a top-level command using the switch route", () => {
  const f = fixture([{ title: "Quit" }]);
  assert.throws(() => f.run(["Quit"]), /Invalid menu route/);
  assert.equal(f.clicks(), 0);
});
