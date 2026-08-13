import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type {
  CommandAction,
  HomebrewAction,
  ServiceAction,
  ServiceConfig,
  ServiceGroup,
  ServiceIcon,
} from "./types";

export const CONFIG_PATH = join(homedir(), ".config/service/config.json");

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
  return value[key];
}

function optionalString(
  value: Record<string, unknown>,
  key: string,
  context: string,
): string | undefined {
  if (value[key] === undefined) return undefined;
  return requiredString(value, key, context);
}

function parseAction(
  value: unknown,
  context: string,
  operation: "start" | "stop" | "restart",
): ServiceAction | undefined {
  if (value === undefined) return undefined;
  if (!isRecord(value)) throw new ConfigError(`${context} must be an object.`);
  const allowedTypes: Record<typeof operation, string[]> = {
    start: ["command", "background", "homebrew"],
    stop: ["command", "homebrew", "listener"],
    restart: ["command", "homebrew"],
  };
  if (
    typeof value.type !== "string" ||
    !allowedTypes[operation].includes(value.type)
  ) {
    throw new ConfigError(`${context}.type is not supported for ${operation}.`);
  }

  if (value.type === "homebrew") {
    const action: HomebrewAction = {
      type: "homebrew",
      service: requiredString(value, "service", context),
    };
    return action;
  }

  if (value.type === "listener") {
    if (
      typeof value.port !== "number" ||
      !Number.isInteger(value.port) ||
      value.port < 1 ||
      value.port > 65_535
    ) {
      throw new ConfigError(`${context}.port must be a valid TCP port.`);
    }
    return {
      type: "listener",
      host: requiredString(value, "host", context),
      port: value.port,
      process: requiredString(value, "process", context),
    };
  }

  if (value.type !== "command" && value.type !== "background") {
    throw new ConfigError(`${context}.type is not supported.`);
  }
  if (
    value.args !== undefined &&
    (!Array.isArray(value.args) ||
      !value.args.every((argument) => typeof argument === "string"))
  ) {
    throw new ConfigError(`${context}.args must be an array of strings.`);
  }

  const action: CommandAction = {
    type: value.type,
    cwd: requiredString(value, "cwd", context),
    executable: requiredString(value, "executable", context),
    args: value.args as string[] | undefined,
    logPath: optionalString(value, "logPath", context),
  };
  if (action.type === "background" && !action.logPath) {
    throw new ConfigError(
      `${context}.logPath is required for background actions.`,
    );
  }
  return action;
}

function parseService(value: unknown, index: number): ServiceConfig {
  const context = `services[${index}]`;
  if (!isRecord(value)) throw new ConfigError(`${context} must be an object.`);

  const group = value.group as ServiceGroup;
  if (group !== "local" && group !== "remote") {
    throw new ConfigError(`${context}.group must be local or remote.`);
  }
  const icon = value.icon as ServiceIcon;
  if (!["blog", "terminal", "document", "dashboard"].includes(icon)) {
    throw new ConfigError(`${context}.icon is not supported.`);
  }

  const service: ServiceConfig = {
    id: requiredString(value, "id", context),
    title: requiredString(value, "title", context),
    group,
    url: requiredString(value, "url", context),
    healthUrl: optionalString(value, "healthUrl", context),
    icon,
    projectPath: optionalString(value, "projectPath", context),
    logPath: optionalString(value, "logPath", context),
    start: parseAction(value.start, `${context}.start`, "start"),
    stop: parseAction(value.stop, `${context}.stop`, "stop"),
    restart: parseAction(value.restart, `${context}.restart`, "restart"),
  };

  try {
    new URL(service.url);
    if (service.healthUrl) new URL(service.healthUrl);
  } catch {
    throw new ConfigError(`${context} contains an invalid URL.`);
  }
  if (
    group === "remote" &&
    (service.start || service.stop || service.restart)
  ) {
    throw new ConfigError(`${context} cannot manage a remote service.`);
  }
  return service;
}

export function parseConfig(value: unknown): ServiceConfig[] {
  if (!isRecord(value) || !Array.isArray(value.services)) {
    throw new ConfigError("Configuration must contain a services array.");
  }

  const services = value.services.map(parseService);
  const ids = new Set<string>();
  for (const service of services) {
    if (ids.has(service.id)) {
      throw new ConfigError(`Duplicate service id: ${service.id}.`);
    }
    ids.add(service.id);
  }
  return services;
}

export async function loadConfig(): Promise<ServiceConfig[]> {
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
