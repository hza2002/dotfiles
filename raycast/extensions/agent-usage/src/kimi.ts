import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { PlanView } from "./usage.ts";

const USAGE_URL = "https://api.kimi.com/coding/v1/usages";
const LOGIN_MESSAGE =
  "请在 Kimi Code 中执行 /usage 刷新登录状态，再重试；未登录时请先执行 /login。";
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
  const used = number(detail.used);
  const limit = number(detail.limit);
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

export async function readKimiUsage(
  read: (path: string) => Promise<string> = (path) => readFile(path, "utf8"),
  request: typeof fetch = fetch,
): Promise<KimiUsage> {
  let token: string;
  try {
    const auth = record(
      JSON.parse(
        await read(join(homedir(), ".kimi-code/credentials/kimi-code.json")),
      ),
    );
    if (typeof auth.access_token !== "string" || !auth.access_token.trim())
      throw new Error();
    token = auth.access_token;
  } catch {
    throw new Error(LOGIN_MESSAGE);
  }
  let response: Response;
  try {
    response = await request(USAGE_URL, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      redirect: "error",
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    throw new Error("Kimi 额度查询失败或超时，请检查网络后刷新。");
  }
  if (response.status === 401 || response.status === 403)
    throw new Error(LOGIN_MESSAGE);
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
