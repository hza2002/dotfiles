import { isIP } from "node:net";
import type { GeoInfo, HostInfo } from "./types.ts";

const GEO_URL = "https://ipwho.is";
const GEO_TIMEOUT_MS = 5_000;

function isPrivateIpv4(address: string): boolean {
  const [first, second] = address.split(".").map(Number);
  return (
    first === 10 ||
    first === 127 ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168) ||
    (first === 169 && second === 254) ||
    (first === 100 && second >= 64 && second <= 127)
  );
}

export function isPrivateAddress(address: string): boolean {
  const version = isIP(address);
  if (version === 4) return isPrivateIpv4(address);
  if (version === 6) {
    const normalized = address.toLowerCase();
    return (
      normalized === "::1" ||
      normalized.startsWith("fc") ||
      normalized.startsWith("fd") ||
      normalized.startsWith("fe80")
    );
  }
  return false;
}

export function flagOf(countryCode: string): string {
  const code = countryCode.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(code)) return "";

  return String.fromCodePoint(
    ...[...code].map((letter) => 0x1f1e6 + letter.charCodeAt(0) - 65),
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseGeoResponse(value: unknown): GeoInfo | undefined {
  if (!isRecord(value) || value.success !== true) return undefined;
  if (typeof value.country_code !== "string" || value.country_code === "") {
    return undefined;
  }

  const connection = isRecord(value.connection) ? value.connection : {};
  return {
    countryCode: value.country_code,
    city: typeof value.city === "string" ? value.city : "",
    isp: typeof connection.isp === "string" ? connection.isp : "",
  };
}

export async function lookupGeo(address: string): Promise<GeoInfo | undefined> {
  const url = new URL(`${GEO_URL}/${encodeURIComponent(address)}`);
  url.searchParams.set("fields", "success,country_code,city,connection");

  const response = await fetch(url, {
    signal: AbortSignal.timeout(GEO_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`Location lookup returned HTTP ${response.status}.`);
  }
  return parseGeoResponse(await response.json());
}

/** The flag rides with the address so both columns keep their right edge. */
export function formatAddress(info: HostInfo): string | undefined {
  const address = info.addresses[0];
  if (address === undefined) return undefined;
  if (info.private) return `🏠 ${address}`;

  const flag = info.geo === undefined ? "" : flagOf(info.geo.countryCode);
  return flag === "" ? address : `${flag} ${address}`;
}

export function describeLocation(info: HostInfo): string {
  if (info.private) return "Local network";

  const parts = [info.geo?.city, info.geo?.isp].filter(
    (part): part is string => part !== undefined && part !== "",
  );
  return parts.length > 0 ? parts.join(" · ") : "Unknown";
}
