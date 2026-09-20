const assert = require("node:assert/strict");
const { userInfo } = require("node:os");
const test = require("node:test");

test("yabai is handed the USER variable the extension host omits", async () => {
  const { yabaiEnv } = await import("../src/space.ts");
  const original = process.env.USER;
  delete process.env.USER;
  try {
    // yabai aborts with "'env USER' not set" without this, and Raycast's
    // extension host runs without it.
    assert.equal(yabaiEnv().USER, userInfo().username);
  } finally {
    if (original !== undefined) process.env.USER = original;
  }
});

test("the created space is the index the second snapshot added", async () => {
  const { newSpaceIndex } = await import("../src/space.ts");
  assert.equal(newSpaceIndex([1, 2, 3], [1, 2, 3, 4]), 4);
});

test("no new index is reported when the snapshot did not grow", async () => {
  const { newSpaceIndex } = await import("../src/space.ts");
  // Either the create failed silently, or a space destroyed at the same moment
  // freed the index the create then took. Both must fall back, not guess.
  assert.equal(newSpaceIndex([1, 2, 3], [1, 2, 3]), undefined);
});

test("an ambiguous diff is refused", async () => {
  const { newSpaceIndex } = await import("../src/space.ts");
  assert.equal(newSpaceIndex([1, 2], [1, 2, 3, 4]), undefined);
});

test("an empty focused space is reused instead of creating another", async () => {
  const { reusableSpace } = await import("../src/space.ts");
  assert.equal(
    reusableSpace(
      [
        { index: 1, hasFocus: false, windows: [11] },
        { index: 2, hasFocus: true, windows: [] },
      ],
      new Set(),
    ),
    2,
  );
});

test("a focused space with windows gets a space of its own", async () => {
  const { reusableSpace } = await import("../src/space.ts");
  assert.equal(
    reusableSpace(
      [
        { index: 1, hasFocus: false, windows: [] },
        { index: 2, hasFocus: true, windows: [11] },
      ],
      new Set(),
    ),
    undefined,
  );
});

test("the command's own panel does not make a space look occupied", async () => {
  const { reusableSpace } = await import("../src/space.ts");
  assert.equal(
    reusableSpace(
      [{ index: 4, hasFocus: true, windows: [21] }],
      new Set([21]), // Raycast's panel, which is open while the command runs
    ),
    4,
  );
});
