import { LocalStorage } from "@raycast/api";

const STORAGE_KEY = "lastConnected";
export const ADDRESS_CACHE_KEY = "addressCache";
export const GEO_CACHE_KEY = "geoCache";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function readRecord(key: string): Promise<Record<string, unknown>> {
  const raw = await LocalStorage.getItem<string>(key);
  if (raw === undefined) return {};

  try {
    const value: unknown = JSON.parse(raw);
    return isRecord(value) ? value : {};
  } catch {
    return {};
  }
}

async function writeRecord(
  key: string,
  value: Record<string, unknown>,
): Promise<void> {
  await LocalStorage.setItem(key, JSON.stringify(value));
}

export async function readCache<T>(key: string): Promise<Record<string, T>> {
  return (await readRecord(key)) as Record<string, T>;
}

export async function writeCache<T>(
  key: string,
  value: Record<string, T>,
): Promise<void> {
  await writeRecord(key, value);
}

/**
 * Connections opened through this extension never reach the shell history,
 * so the extension records its own opens here.
 */
export async function readStoredConnected(): Promise<Map<string, number>> {
  const stored = new Map<string, number>();
  for (const [alias, at] of Object.entries(await readRecord(STORAGE_KEY))) {
    if (typeof at === "number" && Number.isFinite(at)) stored.set(alias, at);
  }
  return stored;
}

export async function recordConnected(
  alias: string,
  at: number = Date.now(),
): Promise<void> {
  const stored = await readStoredConnected();
  stored.set(alias, at);
  await writeRecord(STORAGE_KEY, Object.fromEntries(stored));
}
