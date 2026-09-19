const assert = require("node:assert/strict");
const test = require("node:test");
const { mkdtemp, writeFile } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const { join } = require("node:path");

test("host lines yield aliases and wildcard patterns are ignored", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  assert.deepEqual(
    parseSshConfig(
      [
        "# github over 443",
        "Host github github.com",
        "  HostName ssh.github.com",
        "  Port 443",
        "",
        "Host *",
        "  ServerAliveInterval 300",
        "",
        "Host oracle   # cloud box",
        "  HostName oracle.nand.fun",
      ].join("\n"),
    ),
    [
      { kind: "alias", alias: "github", note: "github over 443" },
      { kind: "alias", alias: "github.com", note: "github over 443" },
      { kind: "alias", alias: "oracle", note: "cloud box" },
    ],
  );
});

test("match blocks, negated patterns, and key=value syntax", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  assert.deepEqual(
    parseSshConfig(
      [
        "Host=first",
        "Match host *.internal",
        "  User deploy",
        "Host second !excluded *",
        "  Port 22",
      ].join("\n"),
    ),
    [
      { kind: "alias", alias: "first" },
      { kind: "alias", alias: "second" },
    ],
  );
});

test("a note block ends at a blank line or another directive", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  assert.deepEqual(
    parseSshConfig(
      [
        "# detached by a blank line",
        "",
        "Host detached",
        "  HostName one.example.com",
        "# trailing the previous block, not the next host",
        "  Port 22",
        "Host attached",
        "  HostName two.example.com",
      ].join("\n"),
    ),
    [
      { kind: "alias", alias: "detached" },
      { kind: "alias", alias: "attached" },
    ],
  );
});

test("commented-out directives never become notes", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  assert.deepEqual(
    parseSshConfig(
      [
        "# Host git-4paradigm git.montecarl0.cn",
        "#   HostName git.montecarl0.cn",
        "#   Port 2222",
        "Host gitlab",
        "  HostName gitlab.example.com",
      ].join("\n"),
    ),
    [{ kind: "alias", alias: "gitlab" }],
  );
});

test("multi-line note blocks are joined and trimmed", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  const [entry] = parseSshConfig(
    [
      "# Oracle Cloud us-phoenix-1",
      "#   跑 sub2api 和备份   ",
      "Host oracle",
    ].join("\n"),
  );

  assert.deepEqual(entry, {
    kind: "alias",
    alias: "oracle",
    note: "Oracle Cloud us-phoenix-1 · 跑 sub2api 和备份",
  });
});

test("long notes are cut and the whole block still wins over nothing", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  const [entry] = parseSshConfig(`# ${"x".repeat(300)}\nHost long`);
  assert.equal(entry.note.length, 160);
  assert.equal(entry.note.endsWith("…"), true);
});

test("include directives keep their position", async () => {
  const { parseSshConfig } = await import("../src/sshconfig.ts");
  assert.deepEqual(
    parseSshConfig(
      ["Host top", "Include conf.d/*.conf", "Host bottom"].join("\n"),
    ),
    [
      { kind: "alias", alias: "top" },
      { kind: "include", value: "conf.d/*.conf" },
      { kind: "alias", alias: "bottom" },
    ],
  );
});

test("aliases load from included files in place and deduplicate", async () => {
  const { loadSshHosts } = await import("../src/sshconfig.ts");
  const directory = await mkdtemp(join(tmpdir(), "sshconfig-"));
  const included = join(directory, "extra.conf");
  await writeFile(included, "# deploy target\nHost included\n  User deploy\n");

  const config = join(directory, "config");
  await writeFile(
    config,
    ["Host first", `Include ${included}`, "Host second", "Host first"].join(
      "\n",
    ),
  );

  assert.deepEqual(await loadSshHosts(config), [
    { alias: "first" },
    { alias: "included", note: "deploy target" },
    { alias: "second" },
  ]);
});

test("wildcard includes load every match and a missing file yields nothing", async () => {
  const { loadSshHosts } = await import("../src/sshconfig.ts");
  const directory = await mkdtemp(join(tmpdir(), "sshconfig-"));
  await writeFile(join(directory, "a.conf"), "Host alpha\n");
  await writeFile(join(directory, "b.conf"), "Host beta\n");

  const config = join(directory, "config");
  await writeFile(config, `Include ${directory}/*.conf\n`);

  assert.deepEqual(await loadSshHosts(config), [
    { alias: "alpha" },
    { alias: "beta" },
  ]);
  assert.deepEqual(await loadSshHosts(join(directory, "missing")), []);
});
