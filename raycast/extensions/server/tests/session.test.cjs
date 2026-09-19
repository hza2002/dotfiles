const assert = require("node:assert/strict");
const test = require("node:test");

test("the remote command attaches to the requested tmux session", async () => {
  const { remoteCommand } = await import("../src/session.ts");
  assert.equal(
    remoteCommand("main"),
    "if command -v tmux >/dev/null 2>&1; " +
      "then exec tmux new-session -A -s 'main'; " +
      'else exec "${SHELL:-/bin/sh}" -l; fi',
  );
});

test("session names survive shell quoting", async () => {
  const { remoteCommand } = await import("../src/session.ts");
  assert.match(remoteCommand("it's here"), /-s 'it'\\''s here';/);
});
