import { execFile } from "node:child_process";
import { isIP } from "node:net";
import { promisify } from "node:util";
import type { SshTarget } from "./types.ts";

const execFileAsync = promisify(execFile);
const PUBLIC_DNS_URL = "https://cloudflare-dns.com/dns-query";
const PUBLIC_DNS_TIMEOUT_MS = 4_000;
const SSH_CONFIG_TIMEOUT_MS = 4_000;
const SSH_CHECK_TIMEOUT_MS = 5_000;
const SSH_OUTPUT_LIMIT_BYTES = 256 * 1024;

export interface ResolvedSshHost {
  target: SshTarget;
  options: Map<string, string[]>;
}

// Options that either have their own row or are already in the target, plus
// the `host` echo of the matched pattern, which is never a setting.
const TARGET_OPTIONS = new Set([
  "host",
  "hostname",
  "user",
  "port",
  "identityfile",
  "userknownhostsfile",
  "globalknownhostsfile",
]);

const BASELINE_SENTINEL = "raycast-server-baseline.invalid";

/** `ssh -G` prints every effective option, one `key value` pair per line. */
export function parseSshOptions(output: string): Map<string, string[]> {
  const options = new Map<string, string[]>();
  for (const line of output.split("\n")) {
    const separator = line.indexOf(" ");
    if (separator === -1) continue;

    const key = line.slice(0, separator);
    options.set(key, [
      ...(options.get(key) ?? []),
      line.slice(separator + 1).trim(),
    ]);
  }
  return options;
}

function firstValue(
  options: Map<string, string[]>,
  key: string,
): string | undefined {
  return options.get(key)?.[0];
}

export function parseSshOutput(output: string): ResolvedSshHost {
  const options = parseSshOptions(output);
  const user = firstValue(options, "user");
  const hostname = firstValue(options, "hostname");
  const port = Number(firstValue(options, "port"));
  if (
    !user ||
    !hostname ||
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65_535
  ) {
    throw new Error("SSH did not return a valid user, hostname, and port.");
  }
  return { target: { user, hostname, port }, options };
}

function runSshG(host: string) {
  return execFileAsync("/usr/bin/ssh", ["-G", "--", host], {
    timeout: SSH_CONFIG_TIMEOUT_MS,
    maxBuffer: SSH_OUTPUT_LIMIT_BYTES,
  });
}

export async function resolveSshTarget(host: string): Promise<ResolvedSshHost> {
  return parseSshOutput((await runSshG(host)).stdout);
}

let baseline: Promise<Map<string, string[]>> | undefined;

/**
 * A name no `Host` block matches resolves to plain OpenSSH defaults plus the
 * user's `Host *` block, which is what "not configured for this host" means.
 */
export function sshBaseline(): Promise<Map<string, string[]>> {
  baseline ??= runSshG(BASELINE_SENTINEL)
    .then(({ stdout }) => parseSshOptions(stdout))
    .catch((error: unknown) => {
      console.error("Server: could not read the SSH defaults", error);
      return new Map<string, string[]>();
    });
  return baseline;
}

export interface SshOption {
  key: string;
  value: string;
}

export function nonDefaultOptions(
  options: Map<string, string[]>,
  reference: Map<string, string[]>,
): SshOption[] {
  // Without a baseline every option would look non-default.
  if (reference.size === 0) return [];

  const entries: SshOption[] = [];
  for (const [key, values] of options) {
    if (TARGET_OPTIONS.has(key)) continue;
    if (values.join("\n") === (reference.get(key) ?? []).join("\n")) continue;
    entries.push({ key, value: values.join(", ") });
  }
  return entries.sort((left, right) => left.key.localeCompare(right.key));
}

export function identityFiles(options: Map<string, string[]>): string[] {
  return options.get("identityfile") ?? [];
}

export function shortKeyType(type: string): string {
  const bare = type.startsWith("ssh-") ? type.slice(4) : type;
  return bare.split("-")[0];
}

export function parseHostKey(output: string): string | undefined {
  for (const line of output.split("\n")) {
    if (line.startsWith("#") || line.trim() === "") continue;
    const [, type] = line.split(/\s+/);
    if (type !== undefined) return shortKeyType(type);
  }
  return undefined;
}

/** Looks the host up in `known_hosts`; `ssh-keygen` handles hashed files. */
export async function readHostKey(
  hostname: string,
  port: number,
): Promise<string | undefined> {
  const query = port === 22 ? hostname : `[${hostname}]:${port}`;
  try {
    const { stdout } = await execFileAsync(
      "/usr/bin/ssh-keygen",
      ["-F", query],
      {
        timeout: SSH_CONFIG_TIMEOUT_MS,
        maxBuffer: SSH_OUTPUT_LIMIT_BYTES,
      },
    );
    return parseHostKey(stdout) ?? "known";
  } catch {
    return undefined;
  }
}

export function formatSshTarget(target: SshTarget): string {
  const hostname = target.hostname.includes(":")
    ? `[${target.hostname}]`
    : target.hostname;
  return `${target.user}@${hostname}:${target.port}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function isLiteralAddress(hostname: string): boolean {
  return isIP(hostname) !== 0;
}

function isClashFakeIp(address: string): boolean {
  if (isIP(address) !== 4) return false;
  const [first, second] = address.split(".").map(Number);
  return first === 198 && (second === 18 || second === 19);
}

export function parsePublicDnsResponse(value: unknown): string[] {
  if (!isRecord(value) || !Array.isArray(value.Answer)) return [];
  return value.Answer.flatMap((answer) => {
    if (!isRecord(answer) || typeof answer.data !== "string") return [];
    return isLiteralAddress(answer.data) && !isClashFakeIp(answer.data)
      ? [answer.data]
      : [];
  });
}

async function queryPublicDns(hostname: string, type: "A" | "AAAA") {
  const url = new URL(PUBLIC_DNS_URL);
  url.searchParams.set("name", hostname);
  url.searchParams.set("type", type);
  const response = await fetch(url, {
    headers: { accept: "application/dns-json" },
    signal: AbortSignal.timeout(PUBLIC_DNS_TIMEOUT_MS),
  });
  if (!response.ok)
    throw new Error(`Public DNS returned HTTP ${response.status}.`);
  return parsePublicDnsResponse(await response.json());
}

export async function resolvePublicAddresses(
  hostname: string,
): Promise<string[]> {
  if (isLiteralAddress(hostname)) return [hostname];

  const results = await Promise.allSettled([
    queryPublicDns(hostname, "A"),
    queryPublicDns(hostname, "AAAA"),
  ]);
  const addresses = [
    ...new Set(
      results.flatMap((result) =>
        result.status === "fulfilled" ? result.value : [],
      ),
    ),
  ];
  if (addresses.length === 0) {
    throw new Error("Public DNS did not return an IP address.");
  }
  return addresses;
}

function sshError(error: unknown): Error {
  if (typeof error === "object" && error !== null && "stderr" in error) {
    const stderr = String(error.stderr).trim();
    const lastLine = stderr.split("\n").at(-1);
    if (lastLine) return new Error(lastLine);
  }
  return new Error("SSH connection check failed.");
}

export async function checkSshConnection(host: string): Promise<number> {
  const startedAt = performance.now();
  try {
    await execFileAsync(
      "/usr/bin/ssh",
      [
        "-T",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=3",
        "-o",
        "ConnectionAttempts=1",
        "-o",
        "ControlMaster=no",
        "-o",
        "ControlPath=none",
        "-o",
        "RemoteCommand=none",
        "--",
        host,
        "true",
      ],
      {
        timeout: SSH_CHECK_TIMEOUT_MS,
        maxBuffer: SSH_OUTPUT_LIMIT_BYTES,
      },
    );
  } catch (error) {
    throw sshError(error);
  }

  return Math.max(1, Math.round(performance.now() - startedAt));
}
