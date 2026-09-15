import { test } from "node:test";
import assert from "node:assert/strict";
import { kimiView, parseKimiUsage, readKimiUsage } from "../src/kimi.ts";
import { rowText } from "../src/usage.ts";

const payload = {
  usage: { used: "20", limit: "100", resetTime: "2026-09-22T02:54:33Z" },
  limits: [
    {
      window: { duration: 300, timeUnit: "TIME_UNIT_MINUTE" },
      detail: { used: "100", limit: "100", resetTime: "2026-09-15T07:54:33Z" },
    },
  ],
};
const credentials = async () => JSON.stringify({ access_token: "test-secret" });

test("Kimi keeps dynamic windows and weekly quota, including exhausted quota", () => {
  const usage = parseKimiUsage(payload);
  assert.deepEqual(
    usage.rows.map(({ title, usedPercent }) => ({ title, usedPercent })),
    [
      { title: "5 小时", usedPercent: 100 },
      { title: "每周", usedPercent: 20 },
    ],
  );
  const view = kimiView(usage);
  assert.equal(view.title, "Kimi Code");
  assert.deepEqual(
    view.rows.map((row) => [row.title, row.remaining]),
    [
      ["5 小时", 0],
      ["每周", 80],
    ],
  );
  assert.equal(
    rowText(view.rows[0], Date.parse("2026-09-15T07:00:00Z")),
    "剩余 \u20070% · 55 分后 · 重置 09-15 15:54",
  );
  assert.match(
    rowText(view.rows[1], Date.parse("2026-10-01")),
    /已到重置时间，请刷新/,
  );
});

test("Kimi uses remaining when the API omits used", () => {
  for (const remaining of ["200", "150", "0"]) {
    const detail = { limit: "200", remaining };
    const view = kimiView(parseKimiUsage({
      usage: detail,
      limits: [{ window: { duration: 300, timeUnit: "TIME_UNIT_MINUTE" }, detail }],
    }));
    assert.deepEqual(view.rows.map((row) => row.remaining), [
      Number(remaining) / 2,
      Number(remaining) / 2,
    ]);
  }
  for (const remaining of [undefined, null, "", "oops", -1, true, 201]) {
    const view = kimiView(parseKimiUsage({ usage: { limit: 200, remaining } }));
    assert.equal(view.rows[0].remaining, null);
  }
  assert.equal(kimiView(parseKimiUsage({
    usage: { used: "50", limit: "200", remaining: "200" },
  })).rows[0].remaining, 75);
});

test("missing and invalid quotas never become a fabricated full balance", () => {
  assert.throws(() => parseKimiUsage(null), /响应无效/);
  assert.deepEqual(kimiView(parseKimiUsage({ limits: [] })).rows, []);
  for (const used of [null, "", "oops", -1, true]) {
    assert.equal(
      parseKimiUsage({ usage: { used, limit: 100 } }).rows[0].usedPercent,
      null,
    );
  }
  const usage = parseKimiUsage({
    usage: { used: 2, limit: 0, resetTime: "bad" },
  });
  assert.equal(usage.rows[0].usedPercent, null);
  assert.equal(usage.rows[0].resetsAt, null);
  assert.equal(kimiView(usage).rows[0].remaining, null);
});

test("query reads the local login and sends the token only to the official endpoint", async () => {
  const usage = await readKimiUsage(
    async (path) => {
      assert.ok(path.endsWith("/.kimi-code/credentials/kimi-code.json"));
      return credentials();
    },
    (async (url, options) => {
      assert.equal(url, "https://api.kimi.com/coding/v1/usages");
      assert.equal(options?.redirect, "error");
      assert.equal(
        new Headers(options?.headers).get("Authorization"),
        "Bearer test-secret",
      );
      assert.ok(options?.signal);
      return Response.json(payload);
    }) as typeof fetch,
  );
  assert.equal(usage.rows.length, 2);
});

test("missing login never queries; authentication errors ask Kimi to refresh", async () => {
  for (const read of [
    async () => "{}",
    async () => "invalid",
    async () => {
      throw new Error("secret");
    },
  ]) {
    await assert.rejects(
      readKimiUsage(read, (async () => {
        assert.fail("must not query");
      }) as typeof fetch),
      /\/login/,
    );
  }
  for (const status of [401, 403]) {
    await assert.rejects(
      readKimiUsage(
        credentials,
        (async () => new Response("secret", { status })) as typeof fetch,
      ),
      /\/usage/,
    );
  }
});

test("network, HTTP and malformed responses do not expose raw server messages", async () => {
  for (const request of [
    async () => {
      throw new Error("test-secret");
    },
    async () => new Response("test-secret", { status: 500 }),
    async () => new Response("test-secret", { status: 200 }),
  ]) {
    await assert.rejects(
      readKimiUsage(credentials, request as typeof fetch),
      (error: Error) => !error.message.includes("test-secret"),
    );
  }
});
