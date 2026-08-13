import { request } from "node:http";
import type { RouteChoice, RouteStatus } from "./types";

const SOCKET_PATH = "/tmp/verge/verge-mihomo.sock";
const MAX_CHAIN_DEPTH = 12;
const LATENCY_TEST_TIMEOUT = 5_000;
const LATENCY_TEST_URL = "https://www.gstatic.com/generate_204";
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
const ROUTES = [
  { id: "default", title: "Default", group: "节点选择" },
  { id: "ai", title: "AI", group: "境外AI" },
] as const;

interface ProxyHistory {
  delay?: number;
  time?: string;
}

interface MihomoProxy {
  type?: string;
  now?: string;
  all?: string[];
  history?: ProxyHistory[];
}

interface ProxiesResponse {
  proxies: Record<string, MihomoProxy>;
}

export class MihomoError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MihomoError";
  }
}

export function requestJson<T>(
  path: string,
  method = "GET",
  body?: unknown,
  timeout = 2_500,
  socketPath = SOCKET_PATH,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? undefined : JSON.stringify(body);
    let settled = false;
    const finish = (callback: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      callback();
    };
    const fail = (error: MihomoError) => finish(() => reject(error));
    const deadline = setTimeout(() => {
      fail(new MihomoError("Clash did not respond in time."));
      req.destroy();
    }, timeout);
    const req = request(
      {
        socketPath,
        path,
        method,
        headers: payload
          ? {
              "Content-Type": "application/json",
              "Content-Length": Buffer.byteLength(payload),
            }
          : undefined,
      },
      (response) => {
        const chunks: Buffer[] = [];
        let receivedBytes = 0;
        response.on("data", (chunk: Buffer) => {
          receivedBytes += chunk.length;
          if (receivedBytes > MAX_RESPONSE_BYTES) {
            response.destroy();
            fail(new MihomoError("Clash returned too much routing data."));
            return;
          }
          chunks.push(chunk);
        });
        response.on("end", () => {
          if (settled) return;
          const status = response.statusCode ?? 500;
          if (status < 200 || status >= 300) {
            fail(new MihomoError("Clash rejected the routing request."));
            return;
          }

          const text = Buffer.concat(chunks).toString("utf8");
          if (!text) {
            finish(() => resolve(undefined as T));
            return;
          }
          try {
            const value = JSON.parse(text) as T;
            finish(() => resolve(value));
          } catch {
            fail(new MihomoError("Clash returned invalid routing data."));
          }
        });
      },
    );

    req.on("error", () => fail(new MihomoError("Clash Verge is unavailable.")));
    if (payload) req.write(payload);
    req.end();
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function getProxies(): Promise<Record<string, MihomoProxy>> {
  const response = await requestJson<ProxiesResponse>("/proxies");
  if (
    !response ||
    typeof response.proxies !== "object" ||
    response.proxies === null
  ) {
    throw new MihomoError("Clash returned invalid routing data.");
  }
  return response.proxies;
}

function resolveProxy(
  proxies: Record<string, MihomoProxy>,
  start: string,
): { resolved: string; delay?: number; testedAt?: string } {
  const visited = new Set<string>();
  let current = start;
  let historyOwner = start;

  for (let depth = 0; depth < MAX_CHAIN_DEPTH; depth++) {
    if (visited.has(current)) return { resolved: current };
    visited.add(current);
    const proxy = proxies[current];
    if (proxy) historyOwner = current;
    const next = proxy?.now;
    if (!next) break;
    current = next;
  }

  const latest = [...(proxies[historyOwner]?.history ?? [])]
    .reverse()
    .find(
      (entry) =>
        typeof entry.delay === "number" &&
        entry.delay > 0 &&
        typeof entry.time === "string" &&
        Number.isFinite(Date.parse(entry.time)),
    );
  return {
    resolved: current,
    delay: latest?.delay,
    testedAt: latest?.time,
  };
}

export function routeFromProxies(
  config: (typeof ROUTES)[number],
  proxies: Record<string, MihomoProxy>,
): RouteStatus {
  const group = proxies[config.group];
  if (
    !group ||
    group.type !== "Selector" ||
    !Array.isArray(group.all) ||
    !group.all.every((name) => typeof name === "string") ||
    typeof group.now !== "string"
  ) {
    return {
      ...config,
      available: false,
      choices: [],
      issue: "Policy group is unavailable in the active profile.",
    };
  }

  const current = resolveProxy(proxies, group.now);
  const choices: RouteChoice[] = [...new Set(group.all)].map((name) => ({
    name,
    ...resolveProxy(proxies, name),
  }));
  return {
    ...config,
    available: true,
    selected: group.now,
    resolved: current.resolved,
    delay: current.delay,
    testedAt: current.testedAt,
    choices,
  };
}

function unavailableRoutes(message: string): RouteStatus[] {
  return ROUTES.map((config) => ({
    ...config,
    available: false,
    choices: [],
    issue: message,
  }));
}

export async function getRouteStatuses(): Promise<RouteStatus[]> {
  try {
    const proxies = await getProxies();
    return ROUTES.map((config) => routeFromProxies(config, proxies));
  } catch (error) {
    const message =
      error instanceof MihomoError
        ? error.message
        : "Clash Verge is unavailable.";
    return unavailableRoutes(message);
  }
}

export async function testRouteLatency(
  groupName: string,
): Promise<Record<string, number>> {
  if (!ROUTES.some((route) => route.group === groupName)) {
    throw new MihomoError("Unknown routing policy.");
  }

  const query = new URLSearchParams({
    url: LATENCY_TEST_URL,
    timeout: String(LATENCY_TEST_TIMEOUT),
    expected: "204",
  });
  const response = await requestJson<unknown>(
    `/group/${encodeURIComponent(groupName)}/delay?${query}`,
    "GET",
    undefined,
    LATENCY_TEST_TIMEOUT + 1_500,
  );
  if (!isRecord(response)) {
    throw new MihomoError("Clash returned invalid latency data.");
  }

  return Object.fromEntries(
    Object.entries(response).filter(
      (entry): entry is [string, number] =>
        typeof entry[1] === "number" &&
        Number.isFinite(entry[1]) &&
        entry[1] > 0,
    ),
  );
}

export async function switchRoute(
  groupName: string,
  choice: string,
): Promise<RouteStatus> {
  const config = ROUTES.find((route) => route.group === groupName);
  if (!config) throw new MihomoError("Unknown routing policy.");

  const before = await getProxies();
  const group = before[groupName];
  if (
    !group ||
    group.type !== "Selector" ||
    !Array.isArray(group.all) ||
    !group.all.includes(choice)
  ) {
    throw new MihomoError(
      "That route is no longer available in the active profile.",
    );
  }

  await requestJson<void>(`/proxies/${encodeURIComponent(groupName)}`, "PUT", {
    name: choice,
  });

  const after = await getProxies();
  if (after[groupName]?.now !== choice)
    throw new MihomoError("Clash did not apply the selected route.");
  return routeFromProxies(config, after);
}
