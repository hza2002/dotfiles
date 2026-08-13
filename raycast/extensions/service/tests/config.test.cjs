const assert = require("node:assert/strict");
const test = require("node:test");

function service(overrides = {}) {
  return {
    id: "example",
    title: "Example",
    group: "local",
    url: "http://127.0.0.1:3000",
    icon: "terminal",
    ...overrides,
  };
}

test("configuration restricts actions to compatible operation slots", async () => {
  const { ConfigError, parseConfig } = await import("../src/config.ts");
  const listener = {
    type: "listener",
    host: "127.0.0.1",
    port: 3000,
    process: "node",
  };
  const background = {
    type: "background",
    cwd: "/tmp",
    executable: "node",
    logPath: "/tmp/example.log",
  };

  assert.doesNotThrow(() =>
    parseConfig({ services: [service({ start: background, stop: listener })] }),
  );
  assert.throws(
    () => parseConfig({ services: [service({ start: listener })] }),
    ConfigError,
  );
  assert.throws(
    () => parseConfig({ services: [service({ restart: background })] }),
    ConfigError,
  );
});
