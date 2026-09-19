const assert = require("node:assert/strict");
const test = require("node:test");

function resolved(target, options = new Map()) {
  return { target, options };
}

const RESOLVED = new Map([
  [
    "oracle",
    resolved(
      { user: "ubuntu", hostname: "oracle.nand.fun", port: 22 },
      new Map([["identityfile", ["~/.ssh/oracle"]]]),
    ),
  ],
  ["134.0.0.1", resolved({ user: "ubuntu", hostname: "134.0.0.1", port: 22 })],
  ["github", resolved({ user: "git", hostname: "ssh.github.com", port: 443 })],
  [
    "github.com",
    resolved({ user: "git", hostname: "ssh.github.com", port: 443 }),
  ],
  ["lwsl", resolved({ user: "bill", hostname: "192.168.1.2", port: 6789 })],
]);

function entries(...aliases) {
  return aliases.map((alias) => ({ alias }));
}

function overlay(overrides = {}) {
  return { include: [], exclude: [], hosts: {}, ...overrides };
}

test("hosts follow recency and keep configuration order for the rest", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hosts = buildHosts(
    entries("oracle", "134.0.0.1", "github", "github.com", "lwsl"),
    RESOLVED,
    new Map([["lwsl", 500]]),
    overlay(),
  );

  assert.deepEqual(
    hosts.map((host) => host.alias),
    ["lwsl", "oracle", "134.0.0.1"],
  );
  assert.deepEqual(hosts[1].target, {
    user: "ubuntu",
    hostname: "oracle.nand.fun",
    port: 22,
  });
  assert.equal(hosts[0].lastConnectedAt, 500);
  assert.equal(hosts[1].title, "oracle");
  assert.equal(hosts[1].tmuxSession, "main");
  assert.deepEqual(hosts[1].sshOptions.get("identityfile"), ["~/.ssh/oracle"]);
});

test("ssh config notes travel with their host", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hosts = buildHosts(
    [{ alias: "oracle", note: "生产机" }, { alias: "lwsl" }],
    RESOLVED,
    new Map(),
    overlay(),
  );

  assert.deepEqual(
    hosts.map((host) => host.note),
    ["生产机", undefined],
  );
  assert.equal("note" in hosts[1], false);
});

test("git-only hosts stay hidden unless the overlay includes them", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hidden = buildHosts(
    entries("oracle", "github", "github.com", "lwsl"),
    RESOLVED,
    new Map(),
    overlay(),
  );
  assert.equal(
    hidden.some((host) => host.target.user === "git"),
    false,
  );

  const shown = buildHosts(
    entries("oracle", "github", "github.com", "lwsl"),
    RESOLVED,
    new Map(),
    overlay({ include: ["github"] }),
  );
  assert.deepEqual(
    shown
      .filter((host) => host.target.user === "git")
      .map((host) => host.alias),
    ["github"],
  );
});

test("hosts sharing a target collapse into the first alias", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hosts = buildHosts(
    entries("github.com", "github"),
    RESOLVED,
    new Map(),
    overlay({ include: ["github", "github.com"] }),
  );

  assert.deepEqual(
    hosts.map((host) => host.alias),
    ["github.com"],
  );
});

test("excluded aliases never appear and unresolved aliases are skipped", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hosts = buildHosts(
    entries("oracle", "lwsl", "ghost"),
    RESOLVED,
    new Map(),
    overlay({ exclude: ["lwsl"] }),
  );

  assert.deepEqual(
    hosts.map((host) => host.alias),
    ["oracle"],
  );
});

test("the overlay renames hosts and picks their tmux session", async () => {
  const { buildHosts } = await import("../src/hosts.ts");
  const hosts = buildHosts(
    entries("oracle"),
    RESOLVED,
    new Map(),
    overlay({
      hosts: { oracle: { title: "Oracle Cloud", tmuxSession: "work" } },
    }),
  );

  assert.equal(hosts[0].title, "Oracle Cloud");
  assert.equal(hosts[0].alias, "oracle");
  assert.equal(hosts[0].tmuxSession, "work");
});
