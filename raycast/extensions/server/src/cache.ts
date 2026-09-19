import type { GeoInfo } from "./types.ts";

export const ADDRESS_TTL_MS = 60 * 60 * 1000;
export const GEO_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export interface AddressRecord {
  addresses: string[];
  at: number;
}

export interface GeoRecord extends GeoInfo {
  at: number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function isFresh(
  at: unknown,
  ttl: number,
  now: number = Date.now(),
): boolean {
  return typeof at === "number" && now - at < ttl;
}

export function usableAddresses(
  record: unknown,
  now: number = Date.now(),
): string[] | undefined {
  if (!isRecord(record) || !Array.isArray(record.addresses)) return undefined;
  if (!isFresh(record.at, ADDRESS_TTL_MS, now)) return undefined;

  const addresses = record.addresses.filter(
    (address): address is string =>
      typeof address === "string" && address !== "",
  );
  return addresses.length > 0 ? addresses : undefined;
}

export function usableGeo(
  record: unknown,
  now: number = Date.now(),
): GeoInfo | undefined {
  if (!isRecord(record) || typeof record.countryCode !== "string") {
    return undefined;
  }
  if (!isFresh(record.at, GEO_TTL_MS, now)) return undefined;

  return {
    countryCode: record.countryCode,
    city: typeof record.city === "string" ? record.city : "",
    isp: typeof record.isp === "string" ? record.isp : "",
  };
}
