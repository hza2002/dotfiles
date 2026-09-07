function run(argv) {
  const se = Application("System Events");
  const proc = se.processes.byName("CC Switch");
  if (!proc.exists()) throw new Error("CC Switch is not running.");
  const tray = proc.menuBars[1].menuBarItems[0];
  function label(title) {
    return title.split(" · ")[0];
  }
  function attribute(item, name, fallback) {
    try {
      const value = item.attributes.byName(name).value();
      return value == null ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }
  function read(menu, depth) {
    if (depth > 6) throw new Error("Unsupported menu nesting.");
    return menu.menuItems().map(function (item) {
      const children = item.menus();
      return {
        title: attribute(item, "AXTitle", ""),
        identifier: attribute(item, "AXIdentifier", ""),
        enabled: !!attribute(item, "AXEnabled", false),
        checked: !!attribute(item, "AXMenuItemMarkChar", ""),
        children: children.length ? read(children[0], depth + 1) : [],
      };
    });
  }
  function openMenu() {
    if (!tray.menus.length) tray.click();
    for (let attempt = 0; attempt < 30 && !tray.menus.length; attempt++)
      delay(0.1);
  }
  function locate(route) {
    let menu = tray.menus[0];
    let found;
    route.forEach(function (title, index) {
      const candidates = menu.menuItems().filter(function (item) {
        const name = attribute(item, "AXTitle", "");
        return (index < route.length - 1 ? label(name) : name) === title;
      });
      if (candidates.length > 1) throw new Error("Menu target is ambiguous.");
      if (candidates.length !== 1) throw new Error("Menu changed.");
      found = candidates[0];
      if (!attribute(found, "AXEnabled", false))
        throw new Error("Menu target is disabled.");
      if (index < route.length - 1) {
        if (!found.menus.length) throw new Error("Menu changed.");
        menu = found.menus[0];
      }
    });
    return found;
  }
  function confirmed(nodes, route) {
    let items = nodes;
    let parent;
    for (let index = 0; index < route.length; index++) {
      const last = index === route.length - 1;
      const matches = items.filter(function (item) {
        return (last ? item.title : label(item.title)) === route[index];
      });
      if (matches.length !== 1 || !matches[0].enabled) return false;
      const item = matches[0];
      if (last) {
        if (
          !item.checked ||
          items.filter(function (sibling) {
            return sibling.checked;
          }).length !== 1
        )
          return false;
        // Provider headers reflect app state; native checkboxes toggle before the handler runs.
        if (route.length === 2) {
          const expected = route[0] + " · " + item.title;
          return (
            parent.title === expected ||
            parent.title.indexOf(expected + " · ") === 0
          );
        }
        return true;
      }
      parent = item;
      items = item.children;
    }
    return false;
  }
  try {
    openMenu();
    if (argv.length) {
      const route = JSON.parse(argv[0]);
      if (
        !Array.isArray(route) ||
        route.length < 2 ||
        route.some(function (value) {
          return typeof value !== "string";
        })
      ) {
        throw new Error("Invalid menu route.");
      }
      const item = locate(route);
      if (!attribute(item, "AXMenuItemMarkChar", "")) {
        item.click();
        delay(0.3);
      }
      for (let attempt = 0; attempt < 20; attempt++) {
        try {
          if (!tray.menus.length) tray.click();
          const snapshot = read(tray.menus[0], 0);
          if (confirmed(snapshot, route)) return JSON.stringify(snapshot);
        } catch (_) {
          // A native menu rebuild can temporarily invalidate accessibility objects.
        }
        delay(0.15);
      }
      throw new Error("Could not verify selection.");
    }
    const snapshot = read(tray.menus[0], 0);
    return JSON.stringify(snapshot);
  } finally {
    se.keyCode(53);
  }
}
