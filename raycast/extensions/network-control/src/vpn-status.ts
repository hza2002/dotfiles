import type {
  VpnId,
  VpnIssue,
  VpnListener,
  VpnProcess,
  VpnState,
  VpnStatus,
} from "./types";

const VPN_STATES = new Set<VpnState>([
  "connected",
  "disconnected",
  "unhealthy",
  "not_configured",
  "disabled",
]);
const VPN_IDS = ["work", "school"] as const;

export class VpnStatusError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "VpnStatusError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseProcess(value: unknown): VpnProcess {
  if (
    !isRecord(value) ||
    (value.role !== "vpn" && value.role !== "proxy") ||
    typeof value.pid !== "number"
  ) {
    throw new VpnStatusError("VPN status contains an invalid process.");
  }
  return {
    role: value.role,
    pid: value.pid,
    elapsed: typeof value.elapsed === "string" ? value.elapsed : "",
  };
}

function parseListener(value: unknown): VpnListener {
  if (
    !isRecord(value) ||
    typeof value.host !== "string" ||
    typeof value.port !== "number"
  )
    throw new VpnStatusError("VPN status contains an invalid listener.");
  return {
    host: value.host,
    port: value.port,
    protocol: typeof value.protocol === "string" ? value.protocol : "",
    listening: value.listening === true,
    owned: value.owned === true,
  };
}

function parseIssue(value: unknown): VpnIssue {
  if (
    !isRecord(value) ||
    typeof value.code !== "string" ||
    typeof value.message !== "string"
  )
    throw new VpnStatusError("VPN status contains an invalid issue.");
  return { code: value.code, message: value.message };
}

export function parseVpnStatus(value: unknown, expectedId: VpnId): VpnStatus {
  if (
    !isRecord(value) ||
    value.schemaVersion !== 1 ||
    value.id !== expectedId ||
    typeof value.state !== "string" ||
    !VPN_STATES.has(value.state as VpnState) ||
    !Array.isArray(value.processes) ||
    !Array.isArray(value.listeners) ||
    !Array.isArray(value.issues) ||
    typeof value.configured !== "boolean" ||
    typeof value.clientInstalled !== "boolean" ||
    (value.clientVersion !== null && typeof value.clientVersion !== "string") ||
    typeof value.logPath !== "string"
  ) {
    throw new VpnStatusError(
      `${expectedId === "work" ? "Work" : "School"} VPN status is incompatible.`,
    );
  }

  return {
    schemaVersion: 1,
    id: expectedId,
    state: value.state as VpnState,
    configured: value.configured,
    clientInstalled: value.clientInstalled,
    clientVersion: value.clientVersion,
    processes: value.processes.map(parseProcess),
    listeners: value.listeners.map(parseListener),
    issues: value.issues.map(parseIssue),
    logPath: value.logPath,
  };
}

export function parseVpnStatuses(
  stdout: string,
  logPaths: Record<VpnId, string>,
): VpnStatus[] {
  let value: unknown;
  try {
    value = JSON.parse(stdout);
  } catch {
    throw new VpnStatusError("via returned invalid status data.");
  }
  if (!Array.isArray(value))
    throw new VpnStatusError("via returned invalid status data.");

  const statuses = new Map<VpnId, VpnStatus>();
  for (const status of value) {
    if (!isRecord(status) || (status.id !== "work" && status.id !== "school")) {
      throw new VpnStatusError("via returned invalid status data.");
    }
    if (statuses.has(status.id)) {
      throw new VpnStatusError(
        `via returned duplicate ${status.id} VPN status.`,
      );
    }
    statuses.set(status.id, parseVpnStatus(status, status.id));
  }
  return VPN_IDS.map(
    (id) =>
      statuses.get(id) ?? {
        schemaVersion: 1,
        id,
        state: "disabled",
        configured: false,
        clientInstalled: false,
        clientVersion: null,
        processes: [],
        listeners: [],
        issues: [],
        logPath: logPaths[id],
      },
  );
}
