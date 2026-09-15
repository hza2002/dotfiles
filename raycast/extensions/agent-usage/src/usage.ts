import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type UsageWindow = { usedPercent: number; resetsAt: number | null };
export type ResetCredit = {
  title: string;
  status: string;
  grantedAt: number | null;
  expiresAt: number | null;
};
export type Usage = {
  email: string;
  planType?: string;
  fiveHour?: UsageWindow;
  weekly?: UsageWindow;
  resetCredits?: number;
  resetCreditDetails?: ResetCredit[];
  ordinaryUsageAllowed?: boolean;
  rateLimitReachedType?: string;
  capturedAt: number;
};

export function parseUsage(
  result: any,
  email: string,
  expectedAccountId: string,
  planType?: string,
): Usage {
  if (result.accountId && result.accountId !== expectedAccountId)
    throw new Error("返回的额度属于其他账号，请重新登录后刷新。");
  const limits = result.rateLimitsByLimitId
    ? result.rateLimitsByLimitId.codex
    : result.rateLimits;
  const usage: Usage = {
    email,
    ...(typeof planType === "string" && planType ? { planType } : {}),
    capturedAt: Date.now(),
  };
  const availableResetCredits = result.rateLimitResetCredits?.availableCount;
  if (
    typeof availableResetCredits === "number" &&
    Number.isInteger(availableResetCredits) &&
    availableResetCredits >= 0
  )
    usage.resetCredits = availableResetCredits;
  const credits = result.rateLimitResetCredits?.credits;
  if (Array.isArray(credits)) {
    usage.resetCreditDetails = credits
      .filter((credit: any) => credit && typeof credit === "object")
      .map((credit: any) => ({
        title:
          typeof credit.title === "string" && credit.title.trim()
            ? credit.title.trim()
            : typeof credit.name === "string" && credit.name.trim()
              ? credit.name.trim()
              : typeof credit.type === "string" && credit.type.trim()
                ? credit.type.trim()
                : typeof credit.creditType === "string" &&
                    credit.creditType.trim()
                  ? credit.creditType.trim()
                  : "重置额度",
        status:
          typeof credit.status === "string" && credit.status.trim()
            ? credit.status.trim()
            : "未知状态",
        grantedAt: epochSeconds(credit.grantedAt),
        expiresAt: epochSeconds(credit.expiresAt),
      }))
      .sort((a, b) => {
        const statusRank = (status: string) =>
          ({ available: 0, redeeming: 1, redeemed: 2, expired: 3, unknown: 4 })[
            status.toLowerCase()
          ] ?? 5;
        const statusOrder = statusRank(a.status) - statusRank(b.status);
        if (statusOrder) return statusOrder;
        if (a.expiresAt === null) return 1;
        if (b.expiresAt === null) return -1;
        return a.expiresAt - b.expiresAt;
      });
  }
  if (typeof result.ordinaryUsageAllowed === "boolean")
    usage.ordinaryUsageAllowed = result.ordinaryUsageAllowed;
  const reachedType =
    limits?.rateLimitReachedType ?? result.rateLimitReachedType;
  if (typeof reachedType === "string" && reachedType.trim())
    usage.rateLimitReachedType = reachedType.trim();
  if (!limits || (limits.limitId && limits.limitId !== "codex")) return usage;
  for (const window of [limits.primary, limits.secondary]) {
    if (
      !window ||
      !Number.isFinite(window.usedPercent) ||
      window.usedPercent < 0 ||
      window.usedPercent > 100
    )
      continue;
    const value = {
      usedPercent: window.usedPercent,
      resetsAt:
        Number.isFinite(window.resetsAt) && window.resetsAt > 0
          ? window.resetsAt
          : null,
    };
    if (window.windowDurationMins === 300) usage.fiveHour = value;
    if (window.windowDurationMins === 10080) usage.weekly = value;
  }
  return usage;
}

async function localAccountId(): Promise<string | undefined> {
  try {
    const auth = JSON.parse(
      await readFile(join(homedir(), ".codex/auth.json"), "utf8"),
    );
    if (auth.auth_mode === "chatgpt" && !auth.OPENAI_API_KEY)
      return auth.tokens?.account_id;
  } catch {
    /* Missing authentication is handled as a signed-out state. */
  }
}

export function queryCodex(
  expectedAccountId: string,
  launch: typeof spawn = spawn,
): Promise<Usage> {
  return new Promise((resolve, reject) => {
    const env: NodeJS.ProcessEnv = {
      ...process.env,
      CODEX_HOME: join(homedir(), ".codex"),
    };
    delete env.OPENAI_API_KEY;
    delete env.CODEX_API_KEY;
    delete env.CODEX_ACCESS_TOKEN;
    const child = launch(
      "/opt/homebrew/bin/codex",
      [
        "-c",
        'model_provider="openai"',
        "-c",
        'chatgpt_base_url="https://chatgpt.com/backend-api/"',
        "app-server",
        "--listen",
        "stdio://",
      ],
      { env, stdio: ["pipe", "pipe", "pipe"] },
    );
    let settled = false;
    let buffer = "";
    let email = "";
    let accountPlanType: string | undefined;
    let stage = 1;
    const finish = (error?: Error, usage?: Usage) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      child.stdin?.end();
      child.kill();
      const forceKill = setTimeout(() => child.kill("SIGKILL"), 1000);
      forceKill.unref();
      child.once("close", () => clearTimeout(forceKill));
      if (error) reject(error);
      else resolve(usage!);
    };
    const timer = setTimeout(
      () => finish(new Error("额度查询超时，请稍后刷新。")),
      20000,
    );
    const send = (id: number, method: string, params?: object) =>
      child.stdin?.write(JSON.stringify({ id, method, params }) + "\n");
    child.once("error", () =>
      finish(
        new Error("无法启动 Codex，请确认已通过 Homebrew 安装 Codex CLI。"),
      ),
    );
    child.once("exit", () =>
      finish(new Error("Codex 查询进程已退出，请重试。")),
    );
    child.stdin?.on("error", () =>
      finish(new Error("无法连接 Codex 查询进程。")),
    );
    child.stderr?.on("data", () => {
      /* Do not surface CLI logs or authentication material. */
    });
    child.stdout?.setEncoding("utf8");
    child.stdout?.on("data", (data: string) => {
      buffer += data;
      if (buffer.length > 1024 * 1024)
        return finish(new Error("Codex 返回的数据过大。"));
      let newline: number;
      while (!settled && (newline = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        try {
          const message = JSON.parse(line);
          if (message.id !== stage || message.method) continue;
          if (message.error)
            return finish(
              new Error("无法获取官方额度，请检查 GPT 登录状态和网络后刷新。"),
            );
          if (stage === 1) {
            child.stdin?.write('{"method":"initialized"}\n');
            stage = 2;
            send(2, "account/read", { refreshToken: false });
          } else if (stage === 2) {
            const account = message.result?.account;
            if (account?.type !== "chatgpt")
              return finish(
                new Error(
                  "请先在 Codex 中登录 GPT 账号，API Key 不支持此额度查询。",
                ),
              );
            email =
              typeof account.email === "string"
                ? account.email
                : "GPT 登录账号";
            accountPlanType =
              typeof account.planType === "string"
                ? account.planType
                : undefined;
            stage = 3;
            send(3, "account/rateLimits/read");
          } else {
            finish(
              undefined,
              parseUsage(
                message.result,
                email,
                expectedAccountId,
                accountPlanType,
              ),
            );
          }
        } catch {
          finish(new Error("额度响应无效或账号不匹配，请重新登录后刷新。"));
        }
      }
    });
    send(1, "initialize", {
      clientInfo: { name: "agent_usage", version: "1.0.0" },
    });
  });
}

export async function readUsage(): Promise<Usage> {
  const before = await localAccountId();
  if (!before) throw new Error("请先在 Codex 中登录 GPT 账号。");
  const usage = await queryCodex(before);
  if ((await localAccountId()) !== before)
    throw new Error("查询期间登录账号已变化，请重新刷新。");
  return usage;
}

export function formatLocalTime(
  timestamp: number,
  timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone,
): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(timestamp);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)!.value;
  return `${value("year")}-${value("month")}-${value("day")} ${value("hour")}:${value("minute")}`;
}

export type QuotaRow = {
  title: string;
  remaining: number | null;
  resetsAt: number | null;
};
export type PlanView = {
  title: string;
  subtitle?: string;
  rows: QuotaRow[];
  note?: string;
  noteDetail?: string;
};

export function codexView(usage: Usage): PlanView {
  const row = (title: string, window: UsageWindow | undefined): QuotaRow => ({
    title,
    remaining: window ? Math.max(0, 100 - window.usedPercent) : null,
    resetsAt: window?.resetsAt ?? null,
  });
  const available = (usage.resetCreditDetails ?? []).filter(
    (credit) => credit.status.toLowerCase() === "available",
  );
  const count = usage.resetCredits ?? (available.length || undefined);
  const nearest = available
    .filter((credit) => credit.expiresAt !== null)
    .sort((a, b) => a.expiresAt! - b.expiresAt!)[0];
  const note = count === undefined ? undefined : `重置券 ×${count}`;
  const noteDetail = nearest
    ? `${creditTitle(nearest.title)} · ${shortResetTime(nearest.expiresAt, Date.now(), true)} 过期`
    : undefined;
  return {
    title: `Codex · ${planText(usage.planType)}`,
    subtitle: usage.email,
    rows: [row("5 小时", usage.fiveHour), row("每周", usage.weekly)],
    ...(note ? { note } : {}),
    ...(note && noteDetail ? { noteDetail } : {}),
  };
}

// The API appends the covered windows, which the quota rows already show.
function creditTitle(title: string): string {
  return title.replace(/\s*[(【][^)】]*[)】]\s*$/u, "").trim() || title;
}

function localParts(timestamp: number) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(timestamp);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)!.value;
  return {
    date: `${value("year")}-${value("month")}-${value("day")}`,
    short: `${value("month")}-${value("day")}`,
    time: `${value("hour")}:${value("minute")}`,
  };
}

// Same-day resets show only HH:mm; later days show MM-DD HH:mm. No year.
export function shortResetTime(
  resetsAt: number | null,
  now: number,
  alwaysDate = false,
): string {
  if (!resetsAt) return "未提供";
  const target = localParts(resetsAt * 1000);
  return !alwaysDate && target.date === localParts(now).date
    ? target.time
    : `${target.short} ${target.time}`;
}

// Figure-space padding keeps the percentage column aligned in proportional fonts.
export function remainingText(row: QuotaRow): string {
  return row.remaining === null
    ? "未提供"
    : `剩余 ${String(Math.round(row.remaining)).padStart(2, "\u2007")}%`;
}

export function resetDetail(row: QuotaRow, now: number): string {
  if (!row.resetsAt) return "重置时间未提供";
  const countdown = countdownText(
    { usedPercent: 0, resetsAt: row.resetsAt },
    now,
  );
  if (countdown === "已到重置时间，请刷新") return countdown;
  // Countdown leads so the fixed-width reset datetime lines up across rows.
  return `${countdown}后 · 重置 ${shortResetTime(row.resetsAt, now, true)}`;
}

export function rowText(row: QuotaRow, now: number): string {
  return `${remainingText(row)} · ${resetDetail(row, now)}`;
}

export function escapeMarkdown(value: string): string {
  return value.replace(/[\\`*_{}\[\]()<>#|]/g, "\\$&");
}

function planText(planType: string | undefined): string {
  if (!planType) return "OpenAI";
  return planType.length
    ? planType[0].toUpperCase() + planType.slice(1)
    : planType;
}

function epochSeconds(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0)
    return value > 100_000_000_000 ? value / 1000 : value;
  if (typeof value === "string") {
    const numeric = Number(value);
    if (Number.isFinite(numeric) && numeric > 0)
      return numeric > 100_000_000_000 ? numeric / 1000 : numeric;
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed) && parsed > 0) return parsed / 1000;
  }
  return null;
}

export function countdownText(
  window: UsageWindow | undefined,
  now: number,
): string {
  if (!window?.resetsAt) return "未知";
  const minutes = Math.ceil((window.resetsAt * 1000 - now) / 60000);
  if (minutes <= 0) return "已到重置时间，请刷新";
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const rest = minutes % 60;
  const parts: string[] = [];
  if (days) parts.push(`${days} 天`);
  if (hours) parts.push(`${hours} 小时`);
  if (rest || parts.length === 0) parts.push(`${rest} 分`);
  return parts.join(" ");
}
