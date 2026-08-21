const assert = require("node:assert/strict");
const test = require("node:test");

test("SSH configuration parsing extracts hostname and port", async () => {
  const { parseSshConfig } = await import("../src/probe.ts");
  assert.deepEqual(
    parseSshConfig("host example\nhostname server.example.com\nport 2222\n"),
    { hostname: "server.example.com", port: 2222 },
  );
});

test("SSH configuration parsing rejects invalid targets", async () => {
  const { parseSshConfig } = await import("../src/probe.ts");
  assert.throws(() => parseSshConfig("hostname example.com\nport 0\n"));
  assert.throws(() => parseSshConfig("port 22\n"));
});

test("SSH target formatting does not replace hostnames with DNS addresses", async () => {
  const { formatSshTarget } = await import("../src/probe.ts");
  assert.equal(
    formatSshTarget({
      hostname: "server.example.com",
      address: "198.18.0.1",
      port: 22,
    }),
    "server.example.com:22",
  );
});

test("SSH target formatting handles literal IPv6 addresses", async () => {
  const { formatSshTarget } = await import("../src/probe.ts");
  assert.equal(
    formatSshTarget({ hostname: "2001:db8::1", port: 2222 }),
    "[2001:db8::1]:2222",
  );
});

test("public DNS parsing keeps addresses and rejects Clash fake IPs", async () => {
  const { parsePublicDnsResponse } = await import("../src/probe.ts");
  assert.deepEqual(
    parsePublicDnsResponse({
      Answer: [
        { data: "203.0.113.10" },
        { data: "198.18.0.1" },
        { data: "198.19.255.254" },
        { data: "2001:db8::10" },
        { data: "not-an-address" },
      ],
    }),
    ["203.0.113.10", "2001:db8::10"],
  );
});

test("literal addresses bypass public DNS lookup", async () => {
  const { resolvePublicAddresses } = await import("../src/probe.ts");
  assert.deepEqual(await resolvePublicAddresses("192.0.2.10"), [
    "192.0.2.10",
  ]);
  assert.deepEqual(await resolvePublicAddresses("2001:db8::10"), [
    "2001:db8::10",
  ]);
});
