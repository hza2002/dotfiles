import { execFile, spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);
export type OfficialProvider = { name: string; accountId: string | null };
export type UsageWindow = { usedPercent: number; resetsAt: number | null };
export type Usage = {
  email: string;
  fiveHour?: UsageWindow;
  weekly?: UsageWindow;
  capturedAt: number;
};

export async function officialProviders(): Promise<OfficialProvider[]> {
  // Read only the identity needed to associate menu entries with official accounts.
  const { stdout } = await exec(
    "/usr/bin/sqlite3",
    [
      "-readonly",
      "-json",
      join(homedir(), ".cc-switch/cc-switch.db"),
      `SELECT name, category,
      CASE WHEN category = 'official'
        AND json_extract(settings_config, '$.auth.auth_mode') = 'chatgpt'
        AND json_extract(settings_config, '$.auth.OPENAI_API_KEY') IS NULL THEN
        json_extract(settings_config, '$.auth.tokens.account_id') END AS accountId
      FROM providers WHERE app_type = 'codex'`,
    ],
    { timeout: 5000, maxBuffer: 1024 * 1024 },
  );
  const rows = JSON.parse(stdout || "[]") as Array<
    OfficialProvider & { category: string | null }
  >;
  return rows.filter(
    (row) =>
      row.category === "official" &&
      rows.filter((other) => other.name === row.name).length === 1,
  );
}

export function parseUsage(
  result: any,
  email: string,
  expectedAccountId: string,
): Usage {
  if (result.accountId && result.accountId !== expectedAccountId)
    throw new Error("返回的额度属于其他账号，请重新登录后刷新。");
  const limits = result.rateLimitsByLimitId
    ? result.rateLimitsByLimitId.codex
    : result.rateLimits;
  const usage: Usage = { email, capturedAt: Date.now() };
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
            stage = 3;
            send(3, "account/rateLimits/read");
          } else {
            finish(
              undefined,
              parseUsage(message.result, email, expectedAccountId),
            );
          }
        } catch {
          finish(new Error("额度响应无效或账号不匹配，请重新登录后刷新。"));
        }
      }
    });
    send(1, "initialize", {
      clientInfo: { name: "cc_switch_usage", version: "1.0.0" },
    });
  });
}

export async function readUsage(provider: OfficialProvider): Promise<Usage> {
  const before = await localAccountId();
  if (!before) throw new Error("请先在 Codex 中登录 GPT 账号。");
  if (!provider.accountId || before !== provider.accountId)
    throw new Error(
      "本机 GPT 登录账号与此官方 provider 不匹配，请同步登录后刷新。",
    );
  const usage = await queryCodex(before);
  if ((await localAccountId()) !== before)
    throw new Error("查询期间登录账号已变化，请重新刷新。");
  return usage;
}

export function resetText(window: UsageWindow | undefined): string {
  if (!window?.resetsAt) return "未提供重置时间";
  return formatLocalTime(window.resetsAt * 1000);
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

export function usageMarkdown(
  usage: Usage | undefined,
  error: string | undefined,
  now: number,
): string {
  if (error) return `### OpenAI 额度\n\n${error}`;
  if (!usage) return "### OpenAI 额度\n\n正在查询…";
  const section = (title: string, window: UsageWindow | undefined) =>
    `### ${title} · ${window ? `剩余 ${100 - window.usedPercent}%` : "未提供此窗口"}\n\n` +
    (window
      ? `重置于 ${resetText(window)}  \n${countdownText(window, now)}${window.resetsAt && window.resetsAt * 1000 > now ? "后重置" : ""}`
      : "");
  const email = usage.email.replace(/[\\`*_{}\[\]()<>#|]/g, "\\$&");
  return [
    section("5 小时", usage.fiveHour),
    section("每周", usage.weekly),
    `---\n\n${email}  \n${Intl.DateTimeFormat().resolvedOptions().timeZone}  \n更新于 ${formatLocalTime(usage.capturedAt)}`,
  ].join("\n\n");
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
  return `${days ? `${days} 天 ` : ""}${hours} 小时 ${minutes % 60} 分`;
}
