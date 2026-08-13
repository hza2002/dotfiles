import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { runAppleScript } from "@raycast/utils";
import type { VpnAction, VpnId, VpnStatus } from "./types";
import { parseVpnStatus, parseVpnStatuses, VpnStatusError } from "./vpn-status";

const execFileAsync = promisify(execFile);
const EXEC_PATH = [
  "/opt/homebrew/bin",
  "/usr/local/bin",
  "/usr/bin",
  "/bin",
  "/usr/sbin",
  "/sbin",
  join(homedir(), ".local/bin"),
].join(":");

const VIA_PATH = join(homedir(), ".local/bin/via");
const VPN_CONFIG: Record<VpnId, { logPath: string }> = {
  work: {
    logPath: join(homedir(), ".local/var/log/zju-connect.log"),
  },
  school: {
    logPath: join(homedir(), ".local/var/log/via-school.log"),
  },
};

const VPN_IDS = ["work", "school"] as const;

export class VpnError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "VpnError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseStatus(stdout: string, expectedId: VpnId): VpnStatus {
  let value: unknown;
  try {
    value = JSON.parse(stdout);
  } catch {
    throw new VpnError(
      `${expectedId === "work" ? "Work" : "School"} VPN returned invalid status data.`,
    );
  }

  try {
    return parseVpnStatus(value, expectedId);
  } catch (error) {
    if (error instanceof VpnStatusError) throw new VpnError(error.message);
    throw error;
  }
}

async function execute(args: string[], timeout: number): Promise<string> {
  try {
    const { stdout } = await execFileAsync(VIA_PATH, args, {
      env: { ...process.env, PATH: EXEC_PATH },
      timeout,
      maxBuffer: 1024 * 1024,
      encoding: "utf8",
    });
    return stdout;
  } catch (error) {
    const detail = errorDetail(error);
    throw new VpnError(
      detail ? `via failed: ${detail}` : "via command failed.",
    );
  }
}

function errorDetail(error: unknown): string | undefined {
  if (!isRecord(error)) return undefined;
  const stderr = typeof error.stderr === "string" ? error.stderr.trim() : "";
  if (stderr) return stderr.slice(0, 300);
  return typeof error.message === "string"
    ? error.message.slice(0, 300)
    : undefined;
}

export async function getVpnStatus(id: VpnId): Promise<VpnStatus> {
  const stdout = await execute([id, "status", "--json"], 5_000);
  return parseStatus(stdout, id);
}

function unavailableStatus(id: VpnId, error: unknown): VpnStatus {
  const message =
    error instanceof VpnError
      ? error.message
      : `${id === "work" ? "Work" : "School"} VPN is unavailable.`;
  return {
    schemaVersion: 1,
    id,
    state: "unhealthy",
    configured: false,
    clientInstalled: false,
    clientVersion: null,
    processes: [],
    listeners: [],
    issues: [{ code: "status_unavailable", message }],
    logPath: VPN_CONFIG[id].logPath,
  };
}

export async function getVpnStatuses(): Promise<VpnStatus[]> {
  try {
    const stdout = await execute(["vpn", "status", "--json"], 5_000);
    return parseVpnStatuses(
      stdout,
      Object.fromEntries(
        VPN_IDS.map((id) => [id, VPN_CONFIG[id].logPath]),
      ) as Record<VpnId, string>,
    );
  } catch (error) {
    return VPN_IDS.map((id) => unavailableStatus(id, error));
  }
}

function connectArgs(id: VpnId): string[] {
  return id === "school" ? ["on", "--non-interactive"] : ["on"];
}

export async function runVpnAction(
  id: VpnId,
  action: VpnAction,
): Promise<VpnStatus> {
  const before = await getVpnStatus(id);
  if (before.state === "not_configured") {
    throw new VpnError(
      `${id === "work" ? "Work" : "School"} VPN needs setup before it can connect.`,
    );
  }

  if (action === "connect" && before.state !== "connected") {
    await execute([id, ...connectArgs(id)], id === "school" ? 60_000 : 45_000);
  } else if (action === "disconnect" && before.state !== "disconnected") {
    await execute([id, "off"], 15_000);
  } else if (action === "reconnect") {
    if (before.state !== "disconnected") await execute([id, "off"], 15_000);
    await execute([id, ...connectArgs(id)], id === "school" ? 60_000 : 45_000);
  }

  const after = await getVpnStatus(id);
  const expected = action === "disconnect" ? "disconnected" : "connected";
  if (after.state !== expected) {
    throw new VpnError(
      `${id === "work" ? "Work" : "School"} VPN did not reach the expected state.`,
    );
  }
  return after;
}

export async function openSetupInGhostty(id: VpnId): Promise<void> {
  const workSetup = [
    'config="$("$HOME/.local/bin/via" work setup)"',
    'exec nvim "$config"',
  ].join("; ");
  const schoolSetup = 'exec "$HOME/.local/bin/via" school on';
  const command = `/bin/zsh -lc ${shellQuote(id === "work" ? workSetup : schoolSetup)}`;

  await runAppleScript(
    `on run argv
      set shellCommand to item 1 of argv
      tell application "Ghostty"
        set surfaceConfig to new surface configuration
        set command of surfaceConfig to shellCommand
        set wait after command of surfaceConfig to false
        set setupWindow to new window with configuration surfaceConfig
        activate window setupWindow
      end tell
    end run`,
    [command],
  );
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}
