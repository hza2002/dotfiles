import { chmod, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { PlanView } from "./usage.ts";

const USAGE_URL = "https://api.kimi.com/coding/v1/usages";
const TOKEN_URL = "https://auth.kimi.com/api/oauth/token";
const CLIENT_ID = "17e5f671-d194-4dfb-9706-5516cb48c098";
const CREDENTIALS_PATH = join(
  homedir(),
  ".kimi-code/credentials/kimi-code.json",
);
const LOGIN_MESSAGE =
  "请在 Kimi Code 中执行 /usage 刷新登录状态，再重试；未登录时请先执行 /login。";
// Treat the token as expired this early to avoid racing the server clock.
const EXPIRY_SKEW_SECONDS = 60;
type Row = {
  title: string;
  usedPercent: number | null;
  resetsAt: number | null;
};
export type KimiUsage = { rows: Row[]; capturedAt: number };

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
function number(value: unknown): number | null {
  if (typeof value !== "number" && (typeof value !== "string" || !value.trim()))
    return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}
function row(raw: unknown, title: string): Row | undefined {
  const detail = record(raw);
  if (!Object.keys(detail).length) return;
  let used = number(detail.used);
  const limit = number(detail.limit);
  const remaining = number(detail.remaining);
  // The API can omit used when the full quota remains.
  if (
    detail.used === undefined &&
    limit !== null &&
    remaining !== null &&
    remaining <= limit
  )
    used = limit - remaining;
  const reset =
    typeof detail.resetTime === "string" ? Date.parse(detail.resetTime) : NaN;
  return {
    title,
    usedPercent:
      used !== null && limit !== null && limit > 0
        ? (used / limit) * 100
        : null,
    resetsAt: Number.isFinite(reset) && reset > 0 ? reset / 1000 : null,
  };
}
function windowTitle(raw: unknown, index: number): string {
  const window = record(raw);
  const duration = number(window.duration);
  const unit = {
    TIME_UNIT_MINUTE: "分钟",
    TIME_UNIT_HOUR: "小时",
    TIME_UNIT_DAY: "天",
    TIME_UNIT_WEEK: "周",
  }[String(window.timeUnit)];
  if (!duration || !unit) return `额度窗口 ${index + 1}`;
  if (window.timeUnit === "TIME_UNIT_MINUTE" && duration % 60 === 0)
    return `${duration / 60} 小时`;
  return `${duration} ${unit}`;
}

// Matches Kimi Code 0.41.0's /usage: top-level usage is the weekly quota.
export function parseKimiUsage(payload: unknown): KimiUsage {
  const data = record(payload);
  if (!Object.keys(data).length)
    throw new Error("Kimi 额度响应无效，请刷新重试。");
  const rows: Row[] = [];
  if (Array.isArray(data.limits))
    data.limits.forEach((item, index) => {
      const limit = record(item);
      const parsed = row(limit.detail, windowTitle(limit.window, index));
      if (parsed) rows.push(parsed);
    });
  const weekly = row(data.usage, "每周");
  if (weekly) rows.push(weekly);
  return { rows, capturedAt: Date.now() };
}

type Credentials = {
  access_token: string;
  refresh_token?: string;
  expires_at?: number;
  expires_in?: number;
  scope?: string;
  token_type?: string;
};

function parseCredentials(raw: string): Credentials {
  const auth = record(JSON.parse(raw));
  if (typeof auth.access_token !== "string" || !auth.access_token.trim())
    throw new Error();
  const cred: Credentials = { access_token: auth.access_token };
  if (typeof auth.refresh_token === "string" && auth.refresh_token.trim())
    cred.refresh_token = auth.refresh_token;
  for (const key of ["expires_at", "expires_in"] as const)
    if (typeof auth[key] === "number" && Number.isFinite(auth[key]))
      cred[key] = auth[key];
  if (typeof auth.scope === "string") cred.scope = auth.scope;
  if (typeof auth.token_type === "string") cred.token_type = auth.token_type;
  return cred;
}

function expiringSoon(cred: Credentials): boolean {
  return (
    cred.expires_at !== undefined &&
    cred.expires_at - Date.now() / 1000 < EXPIRY_SKEW_SECONDS
  );
}

async function writeCredentials(cred: Credentials): Promise<void> {
  const tmp = `${CREDENTIALS_PATH}.tmp`;
  await writeFile(tmp, JSON.stringify(cred));
  await chmod(tmp, 0o600);
  await rename(tmp, CREDENTIALS_PATH);
}

async function refreshToken(
  cred: Credentials,
  request: typeof fetch,
): Promise<Credentials> {
  if (!cred.refresh_token) throw new Error(LOGIN_MESSAGE);
  let response: Response;
  try {
    response = await request(TOKEN_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: new URLSearchParams({
        client_id: CLIENT_ID,
        grant_type: "refresh_token",
        refresh_token: cred.refresh_token,
      }),
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new Error("Kimi 登录状态刷新失败，请检查网络后重试。");
  }
  if (!response.ok) throw new Error(LOGIN_MESSAGE);
  const body = record(await response.json().catch(() => null));
  if (typeof body.access_token !== "string" || !body.access_token.trim())
    throw new Error(LOGIN_MESSAGE);
  const expiresIn = number(body.expires_in) ?? 900;
  return {
    access_token: body.access_token,
    refresh_token:
      typeof body.refresh_token === "string" && body.refresh_token.trim()
        ? body.refresh_token
        : cred.refresh_token,
    expires_at: Math.floor(Date.now() / 1000) + expiresIn,
    expires_in: expiresIn,
    scope:
      typeof body.scope === "string" ? body.scope : (cred.scope ?? "kimi-code"),
    token_type:
      typeof body.token_type === "string" ? body.token_type : "Bearer",
  };
}

async function requestUsages(
  cred: Credentials,
  request: typeof fetch,
): Promise<Response> {
  try {
    return await request(USAGE_URL, {
      headers: {
        Authorization: `Bearer ${cred.access_token}`,
        Accept: "application/json",
      },
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new Error("Kimi 额度查询失败或超时，请检查网络后刷新。");
  }
}

export async function readKimiUsage(
  read: (path: string) => Promise<string> = (path) => readFile(path, "utf8"),
  request: typeof fetch = fetch,
  save: (cred: Credentials) => Promise<void> = writeCredentials,
): Promise<KimiUsage> {
  let cred: Credentials;
  try {
    cred = parseCredentials(await read(CREDENTIALS_PATH));
  } catch {
    throw new Error(LOGIN_MESSAGE);
  }
  if (expiringSoon(cred) && cred.refresh_token) {
    cred = await refreshToken(cred, request);
    await save(cred);
  }
  let response = await requestUsages(cred, request);
  if (response.status === 401 || response.status === 403) {
    // The CLI or another client may have just refreshed; re-read the file
    // before spending our own refresh token.
    const latest = await read(CREDENTIALS_PATH)
      .then(parseCredentials)
      .catch(() => null);
    if (
      latest &&
      latest.access_token !== cred.access_token &&
      !expiringSoon(latest)
    ) {
      cred = latest;
    } else {
      cred = await refreshToken(latest ?? cred, request);
      await save(cred);
    }
    response = await requestUsages(cred, request);
    if (response.status === 401 || response.status === 403)
      throw new Error(LOGIN_MESSAGE);
  }
  if (!response.ok)
    throw new Error(
      `Kimi 额度查询失败（HTTP ${response.status}），请稍后刷新。`,
    );
  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new Error("Kimi 额度响应无效，请刷新重试。");
  }
  return parseKimiUsage(payload);
}

// Remaining percent rounded to integers; missing values stay explicit.
export function kimiView(usage: KimiUsage): PlanView {
  return {
    title: "Kimi Code",
    rows: usage.rows.map((row) => ({
      title: row.title,
      remaining:
        row.usedPercent === null
          ? null
          : Math.max(0, Math.round(100 - row.usedPercent)),
      resetsAt: row.resetsAt,
    })),
  };
}
