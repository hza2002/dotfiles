const assert = require("node:assert/strict");
const test = require("node:test");

test("freshness follows the entry TTL", async () => {
  const { isFresh } = await import("../src/cache.ts");
  const now = 1_700_000_000_000;
  assert.equal(isFresh(now - 1_000, 60_000, now), true);
  assert.equal(isFresh(now - 120_000, 60_000, now), false);
  assert.equal(isFresh(undefined, 60_000, now), false);
  assert.equal(isFresh("yesterday", 60_000, now), false);
});

test("address records expire after an hour", async () => {
  const { ADDRESS_TTL_MS, usableAddresses } = await import("../src/cache.ts");
  const now = 1_700_000_000_000;

  assert.deepEqual(
    usableAddresses({ addresses: ["137.131.23.121"], at: now }, now),
    ["137.131.23.121"],
  );
  assert.equal(
    usableAddresses({ addresses: ["137.131.23.121"], at: now - ADDRESS_TTL_MS - 1 }, now),
    undefined,
  );
  assert.equal(usableAddresses({ addresses: [], at: now }, now), undefined);
  assert.equal(usableAddresses({ addresses: [7], at: now }, now), undefined);
  assert.equal(usableAddresses(null, now), undefined);
});

test("location records outlive addresses and fill missing fields", async () => {
  const { GEO_TTL_MS, usableGeo } = await import("../src/cache.ts");
  const now = 1_700_000_000_000;

  assert.deepEqual(usableGeo({ countryCode: "US", at: now }, now), {
    countryCode: "US",
    city: "",
    isp: "",
  });
  assert.equal(
    usableGeo({ countryCode: "US", at: now - GEO_TTL_MS - 1 }, now),
    undefined,
  );
  assert.equal(usableGeo({ at: now }, now), undefined);
  assert.equal(usableGeo(undefined, now), undefined);
});
