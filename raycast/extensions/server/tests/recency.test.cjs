const assert = require("node:assert/strict");
const test = require("node:test");

test("extended history entries carry their timestamps", async () => {
  const { parseHistory } = await import("../src/recency.ts");
  assert.deepEqual(
    parseHistory(": 1700000000:0;ssh oracle\n: 1700000060:0;ls\n"),
    [
      { at: 1700000000000, command: "ssh oracle" },
      { at: 1700000060000, command: "ls" },
    ],
  );
});

test("history without timestamps contributes nothing", async () => {
  const { parseHistory } = await import("../src/recency.ts");
  assert.deepEqual(parseHistory("ssh oracle\n: 1700000000:0;ssh lwsl\n"), [
    { at: 1700000000000, command: "ssh lwsl" },
  ]);
});

test("the first positional argument is the connection target", async () => {
  const { sshTargetOf } = await import("../src/recency.ts");
  const commands = [
    ["ssh oracle", "oracle"],
    ["ssh -v oracle", "oracle"],
    ["ssh -p 2222 bill@host.example.com", "host.example.com"],
    ["ssh -oProxyCommand=nc%h%p oracle", "oracle"],
    [
      "ssh -i ~/.ssh/oracle -o IdentitiesOnly=yes ubuntu@137.131.23.121",
      "137.131.23.121",
    ],
    ["ssh -- oracle true", "oracle"],
    ["ssh oracle 'exec tmux new-session -A -s main'", "oracle"],
    ["mosh oracle", "oracle"],
    ["/usr/bin/ssh oracle", "oracle"],
  ];

  for (const [command, expected] of commands) {
    assert.equal(sshTargetOf(command), expected, command);
  }
});

test("commands that are not remote sessions have no target", async () => {
  const { sshTargetOf } = await import("../src/recency.ts");
  const commands = [
    "ssh-keygen -R api.nand.fun",
    "ssh-copy-id -i key.pub bill@192.0.2.10",
    "ssh-add --apple-use-keychain ~/.ssh/id_ed25519",
    "scp report.pdf oracle:/tmp",
    "ssh",
    "ssh -v",
  ];

  for (const command of commands) {
    assert.equal(sshTargetOf(command), undefined, command);
  }
});

test("the newest matching entry wins and hostnames match their alias", async () => {
  const { lastConnectedFromHistory } = await import("../src/recency.ts");
  const entries = [
    { at: 1000, command: "ssh oracle" },
    { at: 5000, command: "ssh -v oracle" },
    { at: 3000, command: "ssh oracle.nand.fun" },
    { at: 9000, command: "ssh retired-host" },
  ];

  assert.deepEqual(
    [
      ...lastConnectedFromHistory(entries, [
        { alias: "oracle", hostname: "oracle.nand.fun" },
      ]),
    ],
    [["oracle", 5000]],
  );
});

test("column text stays short and tooltips spell out the recency", async () => {
  const { describeLastConnected } = await import("../src/recency.ts");
  const now = 1_700_000_000_000;
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;

  assert.deepEqual(describeLastConnected(undefined, now), {
    text: "—",
    description: "Never",
    tooltip: "Never connected",
  });
  assert.deepEqual(describeLastConnected(now - 30_000, now), {
    text: "1m",
    description: "1 minute ago",
    tooltip: "Last connected 1 minute ago",
  });
  assert.deepEqual(describeLastConnected(now - 5 * minute, now), {
    text: "5m",
    description: "5 minutes ago",
    tooltip: "Last connected 5 minutes ago",
  });
  assert.deepEqual(describeLastConnected(now - 3 * hour, now), {
    text: "3h",
    description: "3 hours ago",
    tooltip: "Last connected 3 hours ago",
  });
  assert.deepEqual(describeLastConnected(now - 5 * day, now), {
    text: "5d",
    description: "5 days ago",
    tooltip: "Last connected 5 days ago",
  });
  assert.deepEqual(describeLastConnected(now - 60 * day, now), {
    text: "2mo",
    description: "2 months ago",
    tooltip: "Last connected 2 months ago",
  });
  assert.deepEqual(describeLastConnected(now - 800 * day, now), {
    text: "2y",
    description: "2 years ago",
    tooltip: "Last connected 2 years ago",
  });
});
