import {
  usableAddresses,
  usableGeo,
  type AddressRecord,
  type GeoRecord,
} from "./cache.ts";
import { isPrivateAddress, lookupGeo } from "./geo.ts";
import { isLiteralAddress, resolvePublicAddresses } from "./probe.ts";
import {
  ADDRESS_CACHE_KEY,
  GEO_CACHE_KEY,
  readCache,
  writeCache,
} from "./store.ts";
import type { GeoInfo, Host, HostInfo } from "./types.ts";

function literalAddresses(host: Host): string[] | undefined {
  return isLiteralAddress(host.target.hostname)
    ? [host.target.hostname]
    : undefined;
}

function buildInfo(addresses: string[], geo: GeoInfo | undefined): HostInfo {
  const isPrivate = addresses.length > 0 && isPrivateAddress(addresses[0]);
  return { addresses, private: isPrivate, geo: isPrivate ? undefined : geo };
}

async function readCaches(): Promise<
  [Record<string, AddressRecord>, Record<string, GeoRecord>]
> {
  return Promise.all([
    readCache<AddressRecord>(ADDRESS_CACHE_KEY),
    readCache<GeoRecord>(GEO_CACHE_KEY),
  ]);
}

/** What the caches and literal addresses already know, without any network. */
export async function readCachedInfo(
  hosts: Host[],
): Promise<Map<string, HostInfo>> {
  const [addresses, geo] = await readCaches();
  const infos = new Map<string, HostInfo>();

  for (const host of hosts) {
    const known =
      literalAddresses(host) ?? usableAddresses(addresses[host.alias]);
    if (known === undefined) continue;
    infos.set(host.alias, buildInfo(known, usableGeo(geo[known[0]])));
  }

  return infos;
}

/** Fetches what is missing or stale, then writes the refreshed caches back. */
export async function refreshInfo(
  hosts: Host[],
  force: boolean = false,
): Promise<Map<string, HostInfo>> {
  const [addresses, geo] = await readCaches();
  const infos = new Map<string, HostInfo>();

  await Promise.all(
    hosts.map(async (host) => {
      let known =
        literalAddresses(host) ?? usableAddresses(addresses[host.alias]);
      if (known === undefined || force) {
        const resolved = await resolvePublicAddresses(
          host.target.hostname,
        ).catch((error: unknown) => {
          console.error(`Failed to resolve ${host.alias}:`, error);
          return undefined;
        });
        if (resolved !== undefined) {
          addresses[host.alias] = { addresses: resolved, at: Date.now() };
        }
        known = resolved ?? known;
      }
      if (known === undefined) return;

      const address = known[0];
      const isPrivate = isPrivateAddress(address);
      let location = isPrivate ? undefined : usableGeo(geo[address]);
      if (!isPrivate && (location === undefined || force)) {
        const looked = await lookupGeo(address).catch((error: unknown) => {
          console.error(`Failed to locate ${address}:`, error);
          return undefined;
        });
        if (looked !== undefined) {
          geo[address] = { ...looked, at: Date.now() };
          location = looked;
        }
      }

      infos.set(host.alias, buildInfo(known, location));
    }),
  );

  await Promise.all([
    writeCache(ADDRESS_CACHE_KEY, addresses),
    writeCache(GEO_CACHE_KEY, geo),
  ]);

  return infos;
}
