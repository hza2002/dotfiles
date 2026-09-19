const assert = require("node:assert/strict");
const test = require("node:test");
const { mkdtemp, writeFile } = require("node:fs/promises");
const { tmpdir } = require("node:os");
const { join } = require("node:path");

test("an empty overlay configures nothing", async () => {
  const { emptyOverlay, parseOverlay } = await import("../src/config.ts");
  assert.deepEqual(parseOverlay({}), emptyOverlay());
});

test("overlay lists are trimmed and validated", async () => {
  const { OverlayError, parseOverlay } = await import("../src/config.ts");
  assert.deepEqual(
    parseOverlay({ include: [" github "], exclude: ["lwsl", ""] }),
    { include: ["github"], exclude: ["lwsl"], hosts: {} },
  );
  assert.throws(() => parseOverlay({ exclude: "lwsl" }), OverlayError);
  assert.throws(() => parseOverlay({ include: [1] }), OverlayError);
  assert.throws(() => parseOverlay({ hosts: [] }), OverlayError);
});

test("host overrides keep only the fields they provide", async () => {
  const { OverlayError, parseOverlay } = await import("../src/config.ts");
  assert.deepEqual(
    parseOverlay({
      hosts: { oracle: { title: "Oracle Cloud" }, lwsl: { tmuxSession: "wsl" } },
    }).hosts,
    { oracle: { title: "Oracle Cloud" }, lwsl: { tmuxSession: "wsl" } },
  );
  assert.throws(() => parseOverlay({ hosts: { oracle: { title: "" } } }), OverlayError);
  assert.throws(() => parseOverlay({ hosts: { oracle: "Oracle" } }), OverlayError);
});

test("a missing or empty overlay file is not an error", async () => {
  const { emptyOverlay, loadOverlay } = await import("../src/config.ts");
  const directory = await mkdtemp(join(tmpdir(), "overlay-"));

  const missing = await loadOverlay(join(directory, "config.json"));
  assert.deepEqual(missing, { overlay: emptyOverlay() });

  const empty = join(directory, "empty.json");
  await writeFile(empty, "\n");
  assert.deepEqual(await loadOverlay(empty), { overlay: emptyOverlay() });
});

test("a broken overlay is reported and ignored", async () => {
  const { emptyOverlay, loadOverlay } = await import("../src/config.ts");
  const directory = await mkdtemp(join(tmpdir(), "overlay-"));
  const broken = join(directory, "config.json");
  await writeFile(broken, "{ not json");

  const result = await loadOverlay(broken);
  assert.deepEqual(result.overlay, emptyOverlay());
  assert.equal(typeof result.error, "string");
  assert.notEqual(result.error, "");
});
