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
