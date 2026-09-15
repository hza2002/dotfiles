import { test } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough, Writable } from "node:stream";
import type { spawn } from "node:child_process";
import {
  codexView,
  countdownText,
  formatLocalTime,
  parseUsage,
  queryCodex,
  remainingText,
  resetDetail,
  rowText,
  shortResetTime,
} from "../src/usage.ts";

test("local dates use year-month-day, 24-hour time and timezone DST rules", () => {
  const timestamp = Date.parse("2026-09-07T16:25:52Z");
  assert.equal(formatLocalTime(timestamp, "Asia/Taipei"), "2026-09-08 00:25");
  assert.equal(
    formatLocalTime(timestamp, "America/Los_Angeles"),
    "2026-09-07 09:25",
  );
  assert.equal(
    formatLocalTime(Date.parse("2026-03-08T09:59:00Z"), "America/Los_Angeles"),
    "2026-03-08 01:59",
  );
  assert.equal(
    formatLocalTime(Date.parse("2026-03-08T10:00:00Z"), "America/Los_Angeles"),
    "2026-03-08 03:00",
  );
});

const fiveHour = {
  usedPercent: 18,
  windowDurationMins: 300,
  resetsAt: 1800000000,
};
const weekly = {
  usedPercent: 22,
  windowDurationMins: 10080,
  resetsAt: 1800500000,
};

test("selects Codex windows by duration, not position or other model buckets", () => {
  const usage = parseUsage(
    {
      accountId: "account",
      rateLimits: { primary: { ...fiveHour, usedPercent: 99 } },
      rateLimitsByLimitId: {
        codex: { primary: weekly, secondary: fiveHour },
        other: { primary: { ...fiveHour, usedPercent: 99 } },
      },
      rateLimitResetCredits: { availableCount: 3 },
    },
    "test@example.com",
    "account",
  );
  assert.equal(usage.fiveHour?.usedPercent, 18);
  assert.equal(usage.weekly?.usedPercent, 22);
  assert.equal(usage.resetCredits, 3);
  assert.equal(usage.email, "test@example.com");
});

test("parses and sorts reset credit details and diagnostics", () => {
  const usage = parseUsage(
    {
      rateLimitResetCredits: {
        availableCount: 4,
        credits: [
          { title: "Weekly reset", status: "redeemed", expiresAt: 1900000000 },
          {
            name: "Full reset (Weekly + 5 hr)",
            status: "available",
            expiresAt: 1900500000,
          },
          { type: "Full reset", status: "available", expiresAt: null },
        ],
      },
      ordinaryUsageAllowed: false,
      rateLimits: {
        rateLimitReachedType: "weekly",
      },
    },
    "test@example.com",
    "account",
    "pro",
  );
  assert.equal(usage.planType, "pro");
  assert.deepEqual(
    usage.resetCreditDetails?.map((credit) => credit.status),
    ["available", "available", "redeemed"],
  );
  assert.equal(usage.resetCreditDetails?.[0].expiresAt, 1900500000);
  assert.equal(usage.resetCreditDetails?.[1].expiresAt, null);
  assert.equal(usage.ordinaryUsageAllowed, false);
  assert.equal(usage.rateLimitReachedType, "weekly");
  const view = codexView(usage);
  assert.equal(view.title, "Codex · Pro");
  assert.equal(view.note, "重置券 ×4");
  assert.match(view.noteDetail!, /^Full reset · \d{2}-\d{2} \d{2}:\d{2} 过期$/);
});

test("supports legacy snapshots and preserves absent or invalid windows", () => {
  const usage = parseUsage(
    { rateLimits: { primary: fiveHour } },
    "account",
    "account",
  );
  assert.equal(usage.fiveHour?.usedPercent, 18);
  assert.equal(usage.weekly, undefined);
  assert.equal(usage.resetCredits, undefined);
  for (const primary of [
    null,
    { ...fiveHour, usedPercent: -1 },
    { ...fiveHour, usedPercent: 101 },
    { ...fiveHour, usedPercent: "18" },
    { ...fiveHour, windowDurationMins: 60 },
  ]) {
    assert.equal(
      parseUsage({ rateLimits: { primary } }, "", "a").fiveHour,
      undefined,
    );
  }
  assert.equal(
    parseUsage(
      { rateLimitsByLimitId: { other: { primary: fiveHour } } },
      "",
      "a",
    ).fiveHour,
    undefined,
  );
  assert.equal(
    parseUsage({ rateLimits: { limitId: "other", primary: fiveHour } }, "", "a")
      .fiveHour,
    undefined,
  );
  for (const availableCount of [null, -1, 1.5, "3", Infinity]) {
    assert.equal(
      parseUsage({ rateLimitResetCredits: { availableCount } }, "", "a")
        .resetCredits,
      undefined,
    );
  }
  assert.throws(
    () => parseUsage({ accountId: "other" }, "", "account"),
    /其他账号/,
  );
});

test("codex view shows the nearest reset credit on one row", () => {
  const view = codexView({
    email: "test@example.com",
    resetCredits: 3,
    resetCreditDetails: [
      {
        title: "Full reset (Weekly + 5 hr)",
        status: "available",
        grantedAt: null,
        expiresAt: 1900000000,
      },
    ],
    capturedAt: Date.parse("2026-09-07T16:25:52Z"),
  });
  assert.equal(view.note, "重置券 ×3");
  assert.match(
    view.noteDetail!,
    /^Full reset · \d{2}-\d{2} \d{2}:\d{2} 过期$/,
  );
  const bare = codexView({
    email: "test@example.com",
    resetCredits: 3,
    capturedAt: 0,
  });
  assert.equal(bare.note, "重置券 ×3");
  assert.equal(bare.noteDetail, undefined);
  assert.equal(
    codexView({ email: "test@example.com", capturedAt: 0 }).note,
    undefined,
  );
});

test("codex view puts the account email on the title line", () => {
  const view = codexView({
    email: "test@example.com",
    capturedAt: Date.parse("2026-09-07T16:25:52Z"),
  });
  assert.equal(view.subtitle, "test@example.com");
});

test("missing reset times are unknown and elapsed resets require a refresh", () => {
  const window = { usedPercent: 25, resetsAt: 1800000000 };
  assert.equal(
    rowText({ title: "5 小时", remaining: 75, resetsAt: null }, 0),
    "剩余 75% · 重置时间未提供",
  );
  assert.equal(
    remainingText({ title: "5 小时", remaining: 0, resetsAt: null }),
    "剩余 \u20070%",
  );
  assert.equal(
    remainingText({ title: "5 小时", remaining: 100, resetsAt: null }),
    "剩余 100%",
  );
  assert.equal(
    countdownText(window, 1800000000 * 1000),
    "已到重置时间，请刷新",
  );
  assert.equal(
    rowText(
      { title: "每周", remaining: 75, resetsAt: 1800000000 },
      1800000000 * 1000,
    ),
    "剩余 75% · 已到重置时间，请刷新",
  );
  assert.equal(
    countdownText(window, (1800000000 - 90061) * 1000),
    "1 天 1 小时 2 分",
  );
  const usage = parseUsage(
    { rateLimits: { primary: { ...fiveHour, resetsAt: "bad" } } },
    "",
    "a",
  );
  assert.equal(usage.fiveHour?.resetsAt, null);
});

test("compact rows drop the year, zero units and the status line", () => {
  const now = Date.parse("2026-09-15T08:00:00Z"); // 16:00 Asia/Taipei
  const sameDay = Date.parse("2026-09-15T11:38:00Z") / 1000;
  const later = Date.parse("2026-09-19T08:56:00Z") / 1000;
  assert.equal(shortResetTime(sameDay, now), "19:38");
  assert.equal(shortResetTime(later, now), "09-19 16:56");
  assert.equal(shortResetTime(null, now), "未提供");
  assert.equal(
    countdownText({ usedPercent: 0, resetsAt: later }, now),
    "4 天 56 分",
  );
  assert.equal(
    rowText({ title: "每周", remaining: 36, resetsAt: later }, now),
    "剩余 36% · 4 天 56 分后 · 重置 09-19 16:56",
  );
  assert.equal(
    rowText({ title: "5 小时", remaining: 0, resetsAt: sameDay }, now),
    "剩余 \u20070% · 3 小时 38 分后 · 重置 09-15 19:38",
  );
  assert.equal(
    resetDetail({ title: "每周", remaining: 36, resetsAt: null }, now),
    "重置时间未提供",
  );
});

function fakeServer(respond: (request: any) => object | undefined) {
  const requests: any[] = [];
  const child = Object.assign(new EventEmitter(), {
    stdout: new PassThrough(),
    stderr: new PassThrough(),
    stdin: new Writable({
      write(chunk, _encoding, done) {
        const request = JSON.parse(chunk.toString());
        requests.push(request);
        queueMicrotask(() => {
          const response = respond(request);
          if (response) {
            // Notifications and partial JSON lines must not disrupt request sequencing.
            child.stdout.write('{"method":"notice","params":{}}\n');
            const line = JSON.stringify(response) + "\n";
            child.stdout.write(line.slice(0, 8));
            child.stdout.write(line.slice(8));
          }
        });
        done();
      },
    }),
    killed: false,
    kill() {
      this.killed = true;
      queueMicrotask(() => child.emit("close"));
      return true;
    },
  });
  const launch = ((_file: string, args: string[], options: any) => {
    assert.ok(args.includes('model_provider="openai"'));
    assert.ok(
      args.includes('chatgpt_base_url="https://chatgpt.com/backend-api/"'),
    );
    assert.equal(options.env.OPENAI_API_KEY, undefined);
    assert.equal(options.env.CODEX_ACCESS_TOKEN, undefined);
    return child;
  }) as unknown as typeof spawn;
  return { child, launch, requests };
}

test("initializes, verifies ChatGPT login, reads limits and closes the process", async () => {
  const server = fakeServer(({ id }) =>
    id === 1
      ? { id, result: {} }
      : id === 2
        ? {
            id,
            result: {
              account: {
                type: "chatgpt",
                email: "test@example.com",
                planType: "pro",
              },
            },
          }
        : id === 3
          ? {
              id,
              result: {
                accountId: "a",
                rateLimits: { primary: fiveHour, secondary: weekly },
              },
            }
          : undefined,
  );
  const usage = await queryCodex("a", server.launch);
  assert.equal(usage.weekly?.usedPercent, 22);
  assert.equal(usage.planType, "pro");
  assert.deepEqual(
    server.requests.map((r) => r.method),
    ["initialize", "initialized", "account/read", "account/rateLimits/read"],
  );
  assert.ok(server.child.killed);
});

test("API key and signed-out accounts never request quota", async () => {
  for (const account of [null, { type: "apiKey" }]) {
    const server = fakeServer(({ id }) =>
      id === 1
        ? { id, result: {} }
        : id === 2
          ? { id, result: { account } }
          : undefined,
    );
    await assert.rejects(queryCodex("a", server.launch), /登录 GPT/);
    assert.ok(
      !server.requests.some((r) => r.method === "account/rateLimits/read"),
    );
    assert.ok(server.child.killed);
  }
});

test("server errors are sanitized and premature exits reject", async () => {
  const server = fakeServer(({ id }) => ({
    id,
    error: { message: "secret-token" },
  }));
  await assert.rejects(
    queryCodex("a", server.launch),
    (error: Error) => !error.message.includes("secret-token"),
  );
  assert.ok(server.child.killed);
  const exited = fakeServer(() => undefined);
  const pending = queryCodex("a", exited.launch);
  exited.child.emit("exit", 1);
  await assert.rejects(pending, /进程已退出/);
});

test("a stalled server times out and is terminated", async (context) => {
  context.mock.timers.enable({ apis: ["setTimeout"] });
  const server = fakeServer(() => undefined);
  const pending = queryCodex("a", server.launch);
  context.mock.timers.tick(20000);
  await assert.rejects(pending, /超时/);
  assert.ok(server.child.killed);
});
