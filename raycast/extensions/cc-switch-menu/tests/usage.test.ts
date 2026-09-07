import { test } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough, Writable } from "node:stream";
import type { spawn } from "node:child_process";
import {
  countdownText,
  formatLocalTime,
  parseUsage,
  queryCodex,
  resetText,
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
    },
    "test@example.com",
    "account",
  );
  assert.equal(usage.fiveHour?.usedPercent, 18);
  assert.equal(usage.weekly?.usedPercent, 22);
  assert.equal(usage.email, "test@example.com");
});

test("supports legacy snapshots and preserves absent or invalid windows", () => {
  const usage = parseUsage(
    { rateLimits: { primary: fiveHour } },
    "account",
    "account",
  );
  assert.equal(usage.fiveHour?.usedPercent, 18);
  assert.equal(usage.weekly, undefined);
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
  assert.throws(
    () => parseUsage({ accountId: "other" }, "", "account"),
    /其他账号/,
  );
});

test("missing reset times are unknown and elapsed resets require a refresh", () => {
  const window = { usedPercent: 25, resetsAt: 1800000000 };
  assert.equal(resetText(undefined), "未提供重置时间");
  assert.equal(
    countdownText(window, 1800000000 * 1000),
    "已到重置时间，请刷新",
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
            result: { account: { type: "chatgpt", email: "test@example.com" } },
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
