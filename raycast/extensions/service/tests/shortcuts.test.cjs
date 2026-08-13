const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const test = require("node:test");

test("stop uses Command-Backspace instead of Raycast Common.Remove", () => {
  const source = readFileSync("src/shortcuts.ts", "utf8");
  assert.match(source, /modifiers:\s*\["cmd"\]/);
  assert.match(source, /key:\s*"backspace"/);
  assert.doesNotMatch(source, /key:\s*"x"/);
});
