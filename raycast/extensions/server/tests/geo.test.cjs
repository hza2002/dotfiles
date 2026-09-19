const assert = require("node:assert/strict");
const test = require("node:test");

test("country codes become flag emoji", async () => {
  const { flagOf } = await import("../src/geo.ts");
  assert.equal(flagOf("US"), "🇺🇸");
  assert.equal(flagOf("cn"), "🇨🇳");
  assert.equal(flagOf(""), "");
  assert.equal(flagOf("USA"), "");
});

test("private and reserved ranges are recognised", async () => {
  const { isPrivateAddress } = await import("../src/geo.ts");
  const privateAddresses = [
    "192.168.1.2",
    "10.0.0.5",
    "172.16.0.1",
    "172.31.255.254",
    "127.0.0.1",
    "169.254.1.1",
    "100.64.0.1",
    "::1",
    "fd00::1",
    "fe80::1",
  ];
  for (const address of privateAddresses) {
    assert.equal(isPrivateAddress(address), true, address);
  }

  const publicAddresses = [
    "137.131.23.121",
    "113.219.237.121",
    "172.32.0.1",
    "8.8.8.8",
    "2001:db8::1",
  ];
  for (const address of publicAddresses) {
    assert.equal(isPrivateAddress(address), false, address);
  }
});

test("location responses are parsed and rejected", async () => {
  const { parseGeoResponse } = await import("../src/geo.ts");
  assert.deepEqual(
    parseGeoResponse({
      success: true,
      country_code: "US",
      city: "Phoenix",
      connection: { isp: "Oracle Corporation" },
    }),
    { countryCode: "US", city: "Phoenix", isp: "Oracle Corporation" },
  );
  assert.equal(
    parseGeoResponse({ success: false, message: "Reserved range" }),
    undefined,
  );
  assert.equal(parseGeoResponse({ success: true, country_code: "" }), undefined);
  assert.equal(parseGeoResponse("not an object"), undefined);
});

test("addresses carry their flag and describe their location", async () => {
  const { describeLocation, formatAddress } = await import("../src/geo.ts");
  const publicInfo = {
    addresses: ["137.131.23.121"],
    private: false,
    geo: { countryCode: "US", city: "Phoenix", isp: "Oracle Corporation" },
  };

  assert.equal(formatAddress(publicInfo), "🇺🇸 137.131.23.121");
  assert.equal(describeLocation(publicInfo), "Phoenix · Oracle Corporation");

  assert.equal(
    formatAddress({ addresses: ["137.131.23.121"], private: false }),
    "137.131.23.121",
  );
  assert.equal(
    describeLocation({ addresses: ["137.131.23.121"], private: false }),
    "Unknown",
  );
  assert.equal(
    formatAddress({ addresses: ["192.168.1.2"], private: true }),
    "🏠 192.168.1.2",
  );
  assert.equal(
    describeLocation({ addresses: ["192.168.1.2"], private: true }),
    "Local network",
  );
  assert.equal(formatAddress({ addresses: [], private: false }), undefined);
});
