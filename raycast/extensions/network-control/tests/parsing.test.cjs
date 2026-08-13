const assert = require("node:assert/strict");
const { mkdtemp, rm } = require("node:fs/promises");
const { createServer } = require("node:http");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const test = require("node:test");

function vpnStatus(id) {
  return {
    schemaVersion: 1,
    id,
    state: "disconnected",
    configured: true,
    clientInstalled: true,
    clientVersion: null,
    processes: [],
    listeners: [],
    issues: [],
    logPath: `/tmp/${id}.log`,
  };
}

test("missing VPN entries are represented as disabled", async () => {
  const { parseVpnStatuses } = await import("../src/vpn-status.ts");
  const statuses = parseVpnStatuses(JSON.stringify([vpnStatus("school")]), {
    work: "/tmp/work.log",
    school: "/tmp/school.log",
  });

  assert.deepEqual(
    statuses.map(({ id, state }) => ({ id, state })),
    [
      { id: "work", state: "disabled" },
      { id: "school", state: "disconnected" },
    ],
  );
});

test("duplicate VPN entries are rejected", async () => {
  const { parseVpnStatuses } = await import("../src/vpn-status.ts");
  assert.throws(
    () =>
      parseVpnStatuses(JSON.stringify([vpnStatus("work"), vpnStatus("work")]), {
        work: "/tmp/work.log",
        school: "/tmp/school.log",
      }),
    /duplicate work VPN status/,
  );
});

test("malformed nested VPN status data is rejected", async () => {
  const { parseVpnStatuses } = await import("../src/vpn-status.ts");
  const malformed = vpnStatus("work");
  malformed.state = "connected";
  malformed.processes = [{ role: "vpn", pid: "123" }];

  assert.throws(
    () =>
      parseVpnStatuses(JSON.stringify([malformed]), {
        work: "/tmp/work.log",
        school: "/tmp/school.log",
      }),
    /invalid process/,
  );
});

test("route choices must be strings and are deduplicated", async () => {
  const { routeFromProxies } = await import("../src/mihomo.ts");
  const config = { id: "default", title: "Default", group: "Group" };

  assert.equal(
    routeFromProxies(config, {
      Group: { type: "Selector", now: "A", all: ["A", null] },
    }).available,
    false,
  );

  const route = routeFromProxies(config, {
    Group: { type: "Selector", now: "A", all: ["A", "A", "B"] },
  });
  assert.equal(route.available, true);
  assert.deepEqual(
    route.choices.map((choice) => choice.name),
    ["A", "B"],
  );
});

async function withSocketServer(handler, run) {
  const directory = await mkdtemp(join(tmpdir(), "network-control-test."));
  const socketPath = join(directory, "mihomo.sock");
  const server = createServer(handler);
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, resolve);
  });
  try {
    await run(socketPath);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  }
}

test("Mihomo requests have an absolute deadline", async () => {
  await withSocketServer(
    (_request, response) => {
      response.writeHead(200, { "Content-Type": "application/json" });
      const interval = setInterval(() => response.write(" "), 5);
      response.once("close", () => clearInterval(interval));
    },
    async (socketPath) => {
      const { requestJson } = await import("../src/mihomo.ts");
      const startedAt = Date.now();
      await assert.rejects(
        requestJson("/stream", "GET", undefined, 50, socketPath),
        /did not respond in time/,
      );
      assert.ok(Date.now() - startedAt < 500, "deadline was not bounded");
    },
  );
});

test("Mihomo responses have a byte limit", async () => {
  await withSocketServer(
    (_request, response) => {
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(Buffer.alloc(2 * 1024 * 1024 + 1, 0x20));
    },
    async (socketPath) => {
      const { requestJson } = await import("../src/mihomo.ts");
      await assert.rejects(
        requestJson("/large", "GET", undefined, 2_000, socketPath),
        /too much routing data/,
      );
    },
  );
});
