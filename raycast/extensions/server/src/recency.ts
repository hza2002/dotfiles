import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { KnownHost } from "./types.ts";

const HISTORY_PATH = join(homedir(), ".zsh_history");

const PROGRAMS = new Set(["ssh", "mosh", "sftp"]);
// Options that consume the next token, which therefore cannot be the target.
const VALUE_OPTIONS = new Set([
  "-b",
  "-c",
  "-D",
  "-E",
  "-e",
  "-F",
  "-I",
  "-i",
  "-J",
  "-L",
  "-l",
  "-m",
  "-O",
  "-o",
  "-p",
  "-Q",
  "-R",
  "-S",
  "-W",
  "-w",
]);

export interface HistoryEntry {
  at: number;
  command: string;
}

export function parseHistory(text: string): HistoryEntry[] {
  const entries: HistoryEntry[] = [];
  for (const line of text.split("\n")) {
    const match = /^: (\d+):\d+;(.*)$/.exec(line);
    if (match) entries.push({ at: Number(match[1]) * 1000, command: match[2] });
  }
  return entries;
}

/** The first positional argument of an ssh invocation, without its user. */
export function sshTargetOf(command: string): string | undefined {
  const tokens = command.split(/\s+/).filter((token) => token !== "");
  const program = tokens[0]?.split("/").pop() ?? "";
  if (!PROGRAMS.has(program)) return undefined;

  let index = 1;
  while (index < tokens.length && tokens[index].startsWith("-")) {
    index += VALUE_OPTIONS.has(tokens[index]) ? 2 : 1;
  }

  const target = tokens[index];
  if (target === undefined) return undefined;

  const host = target.slice(target.indexOf("@") + 1);
  return host === "" ? undefined : host;
}

export function lastConnectedFromHistory(
  entries: HistoryEntry[],
  hosts: KnownHost[],
): Map<string, number> {
  const aliasesByName = new Map<string, string>();
  for (const host of hosts) {
    aliasesByName.set(host.alias.toLowerCase(), host.alias);
    aliasesByName.set(host.hostname.toLowerCase(), host.alias);
  }

  const lastConnected = new Map<string, number>();
  for (const entry of entries) {
    const target = sshTargetOf(entry.command);
    if (target === undefined) continue;

    const alias = aliasesByName.get(target.toLowerCase());
    if (alias === undefined) continue;
    lastConnected.set(alias, Math.max(lastConnected.get(alias) ?? 0, entry.at));
  }

  return lastConnected;
}

export interface LastConnectedText {
  /** List column, kept within three characters. */
  text: string;
  /** Standalone phrase for the detail pane. */
  description: string;
  tooltip: string;
}

function ago(value: number, unit: string): string {
  return `${value} ${unit}${value === 1 ? "" : "s"} ago`;
}

function entry(text: string, value: number, unit: string): LastConnectedText {
  const description = ago(value, unit);
  return { text, description, tooltip: `Last connected ${description}` };
}

export function describeLastConnected(
  at: number | undefined,
  now: number = Date.now(),
): LastConnectedText {
  if (at === undefined) {
    return { text: "—", description: "Never", tooltip: "Never connected" };
  }

  const minutes = Math.max(1, Math.round((now - at) / 60_000));
  if (minutes < 60) return entry(`${minutes}m`, minutes, "minute");

  const hours = Math.round(minutes / 60);
  if (hours < 24) return entry(`${hours}h`, hours, "hour");

  const days = Math.round(hours / 24);
  if (days < 30) return entry(`${days}d`, days, "day");

  const months = Math.round(days / 30);
  if (months < 10) return entry(`${months}mo`, months, "month");

  return entry(`${Math.round(months / 12)}y`, Math.round(months / 12), "year");
}

export async function readHistory(
  path: string = HISTORY_PATH,
): Promise<HistoryEntry[]> {
  try {
    return parseHistory(await readFile(path, "utf8"));
  } catch {
    return [];
  }
}
