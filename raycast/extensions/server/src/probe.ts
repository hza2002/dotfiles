import { execFile } from "node:child_process";
import { isIP } from "node:net";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const PUBLIC_DNS_URL = "https://cloudflare-dns.com/dns-query";
const PUBLIC_DNS_TIMEOUT_MS = 4_000;
const SSH_CONFIG_TIMEOUT_MS = 4_000;
const SSH_CHECK_TIMEOUT_MS = 5_000;
const SSH_OUTPUT_LIMIT_BYTES = 256 * 1024;

export interface SshTarget {
  hostname: string;
  port: number;
}

export function parseSshConfig(output: string): {
  hostname: string;
  port: number;
} {
  const values = new Map<string, string>();
  for (const line of output.split("\n")) {
    const separator = line.indexOf(" ");
    if (separator === -1) continue;
    values.set(line.slice(0, separator), line.slice(separator + 1).trim());
  }

  const hostname = values.get("hostname");
  const port = Number(values.get("port"));
  if (!hostname || !Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("SSH did not return a valid hostname and port.");
  }
  return { hostname, port };
}

export async function resolveSshTarget(host: string): Promise<SshTarget> {
  const { stdout } = await execFileAsync("/usr/bin/ssh", ["-G", "--", host], {
    timeout: SSH_CONFIG_TIMEOUT_MS,
    maxBuffer: SSH_OUTPUT_LIMIT_BYTES,
  });
  return parseSshConfig(stdout);
}

export function formatSshTarget(target: SshTarget): string {
  const hostname = target.hostname.includes(":")
    ? `[${target.hostname}]`
    : target.hostname;
  return `${hostname}:${target.port}`;
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
