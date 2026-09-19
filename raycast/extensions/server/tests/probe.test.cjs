const assert = require("node:assert/strict");
const test = require("node:test");

test("SSH configuration parsing extracts user, hostname, and port", async () => {
  const { parseSshOutput } = await import("../src/probe.ts");
  const { target } = parseSshOutput(
    "host example\nuser deploy\nhostname server.example.com\nport 2222\n",
  );
  assert.deepEqual(target, {
    user: "deploy",
    hostname: "server.example.com",
    port: 2222,
  });
});

test("SSH configuration parsing rejects incomplete targets", async () => {
  const { parseSshOutput } = await import("../src/probe.ts");
  assert.throws(() =>
    parseSshOutput("user deploy\nhostname example.com\nport 0\n"),
  );
  assert.throws(() => parseSshOutput("hostname example.com\nport 22\n"));
  assert.throws(() => parseSshOutput("user deploy\nport 22\n"));
});

test("SSH options keep every value of a repeated key", async () => {
  const { identityFiles, parseSshOptions } = await import("../src/probe.ts");
  const options = parseSshOptions(
    "identityfile ~/.ssh/one\nidentityfile ~/.ssh/two\nport 22\n",
  );

  assert.deepEqual(options.get("identityfile"), [
    "~/.ssh/one",
    "~/.ssh/two",
  ]);
  assert.deepEqual(options.get("port"), ["22"]);
  assert.deepEqual(identityFiles(options), ["~/.ssh/one", "~/.ssh/two"]);
  assert.deepEqual(identityFiles(new Map()), []);
});

test("non-default options drop whatever the baseline already says", async () => {
  const { nonDefaultOptions, parseSshOptions } = await import("../src/probe.ts");
  const options = parseSshOptions(
    [
      "host example",
      "serveraliveinterval 300",
      "compression no",
      "identitiesonly yes",
      "hostname example.com",
      "port 2222",
      "identityfile ~/.ssh/one",
    ].join("\n"),
  );
  const baseline = parseSshOptions(
    ["serveraliveinterval 300", "compression no", "hostname other.invalid"].join(
      "\n",
    ),
  );

  // Only the host's own setting survives: the baseline match, the target
  // fields, and the identity file all have their own rows.
  assert.deepEqual(nonDefaultOptions(options, baseline), [
    { key: "identitiesonly", value: "yes" },
  ]);
});

test("without a baseline nothing is reported as non-default", async () => {
  const { nonDefaultOptions, parseSshOptions } = await import("../src/probe.ts");
  assert.deepEqual(
    nonDefaultOptions(parseSshOptions("compression yes\n"), new Map()),
    [],
  );
});

test("host key types are shortened from known_hosts output", async () => {
  const { parseHostKey, shortKeyType } = await import("../src/probe.ts");

  assert.equal(shortKeyType("ssh-ed25519"), "ed25519");
  assert.equal(shortKeyType("ecdsa-sha2-nistp256"), "ecdsa");
  assert.equal(shortKeyType("ssh-rsa"), "rsa");

  assert.equal(
    parseHostKey(
      "# Host 137.131.23.121 found: line 12\n137.131.23.121 ssh-ed25519 AAAAC3Nza\n",
    ),
    "ed25519",
  );
  assert.equal(parseHostKey(""), undefined);
  assert.equal(parseHostKey("# Host example.com is not found\n"), undefined);
});

test("SSH target formatting includes the user and brackets IPv6", async () => {
  const { formatSshTarget } = await import("../src/probe.ts");
  assert.equal(
    formatSshTarget({
      user: "ubuntu",
      hostname: "oracle.nand.fun",
      port: 22,
    }),
    "ubuntu@oracle.nand.fun:22",
  );
  assert.equal(
    formatSshTarget({ user: "deploy", hostname: "2001:db8::1", port: 2222 }),
    "deploy@[2001:db8::1]:2222",
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
