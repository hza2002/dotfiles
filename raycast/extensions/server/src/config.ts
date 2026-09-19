import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { Overlay, OverlayHost } from "./types.ts";

export const OVERLAY_PATH = join(homedir(), ".config/server/config.json");

export class OverlayError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OverlayError";
  }
}

export interface OverlayResult {
  overlay: Overlay;
  error?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringList(value: unknown, context: string): string[] {
  if (value === undefined) return [];
  if (
    !Array.isArray(value) ||
    value.some((entry) => typeof entry !== "string")
  ) {
    throw new OverlayError(`${context} must be an array of aliases.`);
  }
  return value.map((entry) => entry.trim()).filter((entry) => entry !== "");
}

function optionalString(
  value: Record<string, unknown>,
  key: string,
  context: string,
): string | undefined {
  if (value[key] === undefined) return undefined;
  if (typeof value[key] !== "string" || value[key].trim() === "") {
    throw new OverlayError(`${context}.${key} must be a non-empty string.`);
  }
  return value[key].trim();
}

function parseHostOverride(value: unknown, context: string): OverlayHost {
  if (!isRecord(value)) throw new OverlayError(`${context} must be an object.`);

  const override: OverlayHost = {};
  const title = optionalString(value, "title", context);
  const tmuxSession = optionalString(value, "tmuxSession", context);
  if (title !== undefined) override.title = title;
  if (tmuxSession !== undefined) override.tmuxSession = tmuxSession;
  return override;
}

export function emptyOverlay(): Overlay {
  return { include: [], exclude: [], hosts: {} };
}

export function parseOverlay(value: unknown): Overlay {
  if (!isRecord(value)) {
    throw new OverlayError("The overlay must be a JSON object.");
  }

  const hosts: Record<string, OverlayHost> = {};
  if (value.hosts !== undefined) {
    if (!isRecord(value.hosts)) {
      throw new OverlayError("hosts must be an object.");
    }
    for (const [alias, override] of Object.entries(value.hosts)) {
      hosts[alias] = parseHostOverride(override, `hosts.${alias}`);
    }
  }

  return {
    include: stringList(value.include, "include"),
    exclude: stringList(value.exclude, "exclude"),
    hosts,
  };
}

/** The overlay is optional: a missing or empty file configures nothing. */
export async function loadOverlay(
  path: string = OVERLAY_PATH,
): Promise<OverlayResult> {
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return { overlay: emptyOverlay() };
  }

  if (raw.trim() === "") return { overlay: emptyOverlay() };

  try {
    return { overlay: parseOverlay(JSON.parse(raw)) };
  } catch (error) {
    return {
      overlay: emptyOverlay(),
      error:
        error instanceof Error ? error.message : "The overlay is not valid.",
    };
  }
}
