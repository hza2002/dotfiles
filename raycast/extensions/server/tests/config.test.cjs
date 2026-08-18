const assert = require("node:assert/strict");
const test = require("node:test");

test("configuration accepts distinct SSH hosts", async () => {
  const { parseConfig } = await import("../src/config.ts");
  assert.deepEqual(
    parseConfig({
      servers: [
        { title: "Primary", host: "primary" },
        { title: "Backup", host: "backup" },
      ],
    }),
    [
      { title: "Primary", host: "primary" },
      { title: "Backup", host: "backup" },
    ],
  );
});

test("configuration trims values and rejects duplicate hosts", async () => {
  const { ConfigError, parseConfig } = await import("../src/config.ts");
  assert.deepEqual(
    parseConfig({ servers: [{ title: " Primary ", host: " primary " }] }),
    [{ title: "Primary", host: "primary" }],
  );
  assert.throws(
    () =>
      parseConfig({
        servers: [
          { title: "Primary", host: "same" },
          { title: "Duplicate", host: "same" },
        ],
      }),
    ConfigError,
  );
});

test("configuration rejects missing fields and malformed roots", async () => {
  const { ConfigError, parseConfig } = await import("../src/config.ts");
  assert.throws(() => parseConfig({}), ConfigError);
  assert.throws(
    () => parseConfig({ servers: [{ title: "Primary", host: "" }] }),
    ConfigError,
  );
});
