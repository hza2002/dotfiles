const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const test = require("node:test");

test("service actions follow the health-state policy", async () => {
  const { canRestartService, canStartService, canStopService } = await import(
    "../src/service-actions.ts"
  );
  const service = {
    start: { type: "command" },
    stop: { type: "command" },
  };

  assert.equal(canStartService(service, "unavailable"), true);
  assert.equal(canStartService(service, "running"), false);
  assert.equal(canStartService(service, "error"), false);
  assert.equal(canStartService(service, "unknown"), false);

  assert.equal(canStopService(service, "running"), true);
  assert.equal(canStopService(service, "error"), true);
  assert.equal(canStopService(service, "unavailable"), false);
  assert.equal(canStopService(service, "unknown"), false);

  assert.equal(canRestartService(service, "running"), true);
  assert.equal(canRestartService(service, "error"), true);
  assert.equal(canRestartService(service, "unavailable"), false);
  assert.equal(canRestartService(service, "unknown"), false);
});

test("service actions acquire a synchronous per-service lock", () => {
  const source = readFileSync("src/index.tsx", "utf8");
  const guard = source.indexOf("activeServices.current.has(service.id)");
  const acquire = source.indexOf("activeServices.current.add(service.id)");
  const firstAwait = source.indexOf("await showToast", acquire);
  const release = source.indexOf("activeServices.current.delete(service.id)");
  const finallyBlock = source.lastIndexOf("finally", release);

  assert.ok(guard >= 0, "missing duplicate-action guard");
  assert.ok(acquire > guard, "the lock must be acquired after the guard");
  assert.ok(firstAwait > acquire, "the lock must be acquired before yielding");
  assert.ok(
    finallyBlock >= 0 && release > finallyBlock,
    "the lock must be released in finally",
  );
});

test("HTTP errors are not treated as a stopped service", async () => {
  const originalFetch = global.fetch;
  let checks = 0;
  global.fetch = async () => {
    checks += 1;
    return { status: checks === 1 ? 500 : 503 };
  };

  try {
    const { waitUntilUnavailable } = await import("../src/health.ts");
    await assert.rejects(
      waitUntilUnavailable(
        { id: "example", title: "Example", url: "http://127.0.0.1" },
        10,
        1,
      ),
      /HTTP 503/,
    );
    assert.ok(checks > 1, "the stop check should retry HTTP errors");
  } finally {
    global.fetch = originalFetch;
  }
});

test("an unreachable service completes the stop wait", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    throw new TypeError("fetch failed", {
      cause: Object.assign(new Error("connection refused"), {
        code: "ECONNREFUSED",
      }),
    });
  };

  try {
    const { waitUntilUnavailable } = await import("../src/health.ts");
    const status = await waitUntilUnavailable(
      { id: "example", title: "Example", url: "http://127.0.0.1" },
      10,
      1,
    );
    assert.equal(status.state, "unavailable");
  } finally {
    global.fetch = originalFetch;
  }
});

test("a TLS failure is not treated as a stopped service", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    throw new TypeError("fetch failed", {
      cause: Object.assign(new Error("certificate has expired"), {
        code: "CERT_HAS_EXPIRED",
      }),
    });
  };

  try {
    const { checkService, waitUntilUnavailable } = await import(
      "../src/health.ts"
    );
    const service = {
      id: "example",
      title: "Example",
      url: "https://example.test",
    };
    assert.equal((await checkService(service)).state, "unknown");
    await assert.rejects(waitUntilUnavailable(service, 5, 1), /fetch failed/);
  } finally {
    global.fetch = originalFetch;
  }
});

test("a reset connection is not treated as a stopped service", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    throw new TypeError("fetch failed", { cause: { code: "ECONNRESET" } });
  };
  try {
    const { checkService, waitUntilUnavailable } = await import(
      "../src/health.ts"
    );
    const service = {
      id: "example",
      title: "Example",
      url: "http://127.0.0.1",
    };
    const status = await checkService(service);
    assert.equal(status.state, "unknown");
    await assert.rejects(
      waitUntilUnavailable(service, 1, 1),
      /fetch failed/,
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test("a timed-out health check is not treated as stopped", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    throw new DOMException("timed out", "TimeoutError");
  };

  try {
    const { waitUntilUnavailable } = await import("../src/health.ts");
    await assert.rejects(
      waitUntilUnavailable(
        { id: "example", title: "Example", url: "http://127.0.0.1" },
        5,
        1,
      ),
      /Health check timed out/,
    );
  } finally {
    global.fetch = originalFetch;
  }
});
