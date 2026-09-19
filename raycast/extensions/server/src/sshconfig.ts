import { glob, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, resolve } from "node:path";

export const SSH_CONFIG_PATH = join(homedir(), ".ssh/config");

const CONFIG_DIR = dirname(SSH_CONFIG_PATH);
const PATTERN = /[*?![\]]/;
const NOTE_LIMIT = 160;

// Commented-out directives must never be mistaken for a host note.
const DIRECTIVE = new RegExp(
  "^(" +
    [
      "host",
      "match",
      "include",
      "hostname",
      "user",
      "port",
      "identityfile",
      "identitiesonly",
      "proxycommand",
      "proxyjump",
      "forwardagent",
      "addkeystoagent",
      "serveraliveinterval",
      "serveralivecountmax",
      "localforward",
      "remoteforward",
      "dynamicforward",
      "requesttty",
      "remotecommand",
      "setenv",
      "sendenv",
    ].join("|") +
    ")\\b",
  "i",
);

export interface SshHostEntry {
  alias: string;
  note?: string;
}

export type SshConfigEntry =
  | { kind: "alias"; alias: string; note?: string }
  | { kind: "include"; value: string };

function splitComment(line: string): { code: string; comment: string } {
  const match = /(^|\s)#/.exec(line);
  if (match === null) return { code: line, comment: "" };

  const hash = match.index + match[1].length;
  return { code: line.slice(0, hash), comment: line.slice(hash + 1).trim() };
}

function splitTokens(line: string): string[] {
  return line.split(/[\s=]+/).filter((token) => token !== "");
}

/** A comment block only counts when it sits directly above the `Host` line. */
function noteFrom(block: string[]): string | undefined {
  const lines = block
    .filter((line) => !DIRECTIVE.test(line))
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter((line) => line !== "");
  if (lines.length === 0) return undefined;

  const note = lines.join(" · ");
  return note.length > NOTE_LIMIT ? `${note.slice(0, NOTE_LIMIT - 1)}…` : note;
}

/**
 * SSH aliases are discovered here; everything about what they mean stays in
 * `ssh -G`, so wildcard blocks and `Match` blocks never become list entries.
 */
export function parseSshConfig(text: string): SshConfigEntry[] {
  const entries: SshConfigEntry[] = [];
  let collecting = true;
  let pending: string[] = [];

  for (const rawLine of text.split("\n")) {
    const { code, comment } = splitComment(rawLine);
    const line = code.trim();

    if (line === "") {
      pending = comment === "" ? [] : [...pending, comment];
      continue;
    }

    const [keyword, ...values] = splitTokens(line);
    if (keyword?.toLowerCase() === "host") {
      collecting = true;
      const note = comment !== "" ? noteFrom([comment]) : noteFrom(pending);
      for (const value of values) {
        if (PATTERN.test(value)) continue;
        entries.push(
          note === undefined
            ? { kind: "alias", alias: value }
            : { kind: "alias", alias: value, note },
        );
      }
    } else if (keyword?.toLowerCase() === "match") {
      collecting = false;
    } else if (keyword?.toLowerCase() === "include" && collecting) {
      for (const value of values) entries.push({ kind: "include", value });
    }

    // Any directive ends the comment block in front of it.
    pending = [];
  }

  return entries;
}

function expandPath(value: string): string {
  if (value === "~") return homedir();
  if (value.startsWith("~/")) return join(homedir(), value.slice(2));
  return isAbsolute(value) ? value : resolve(CONFIG_DIR, value);
}

async function resolveInclude(value: string): Promise<string[]> {
  const path = expandPath(value);
  if (!PATTERN.test(path)) return [path];

  const matches: string[] = [];
  for await (const match of glob(path)) matches.push(match);
  return matches.sort();
}

async function collectEntries(
  path: string,
  seen: Set<string>,
): Promise<SshHostEntry[]> {
  if (seen.has(path)) return [];
  seen.add(path);

  let text: string;
  try {
    text = await readFile(path, "utf8");
  } catch {
    return [];
  }

  const entries: SshHostEntry[] = [];
  for (const entry of parseSshConfig(text)) {
    if (entry.kind === "alias") {
      entries.push(
        entry.note === undefined
          ? { alias: entry.alias }
          : { alias: entry.alias, note: entry.note },
      );
      continue;
    }
    for (const includePath of await resolveInclude(entry.value)) {
      entries.push(...(await collectEntries(includePath, seen)));
    }
  }

  return entries;
}

/** Order follows the configuration so unvisited hosts keep a stable order. */
export async function loadSshHosts(
  path: string = SSH_CONFIG_PATH,
): Promise<SshHostEntry[]> {
  const entries = await collectEntries(path, new Set());
  const aliases = new Set<string>();

  return entries.filter((entry) => {
    if (aliases.has(entry.alias)) return false;
    aliases.add(entry.alias);
    return true;
  });
}
