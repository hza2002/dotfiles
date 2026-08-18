import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ServerConfig } from "./types";

export const CONFIG_PATH = join(homedir(), ".config/server/config.json");

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredString(
  value: Record<string, unknown>,
  key: string,
  context: string,
): string {
  if (typeof value[key] !== "string" || value[key].trim() === "") {
    throw new ConfigError(`${context}.${key} must be a non-empty string.`);
  }
  return value[key].trim();
}

function parseServer(value: unknown, index: number): ServerConfig {
  const context = `servers[${index}]`;
  if (!isRecord(value)) throw new ConfigError(`${context} must be an object.`);

  return {
    title: requiredString(value, "title", context),
    host: requiredString(value, "host", context),
  };
}

export function parseConfig(value: unknown): ServerConfig[] {
  if (!isRecord(value) || !Array.isArray(value.servers)) {
    throw new ConfigError("Configuration must contain a servers array.");
  }

  const servers = value.servers.map(parseServer);
  const hosts = new Set<string>();
  for (const server of servers) {
    if (hosts.has(server.host)) {
      throw new ConfigError(`Duplicate server host: ${server.host}.`);
    }
    hosts.add(server.host);
  }
  return servers;
}

export async function loadConfig(): Promise<ServerConfig[]> {
  let raw: string;
  try {
    raw = await readFile(CONFIG_PATH, "utf8");
  } catch {
    throw new ConfigError(`Configuration not found at ${CONFIG_PATH}.`);
  }

  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new ConfigError(`Configuration at ${CONFIG_PATH} is not valid JSON.`);
  }
  return parseConfig(value);
}
