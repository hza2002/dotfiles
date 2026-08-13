import { execFile, spawn } from "node:child_process";
import { closeSync, mkdirSync, openSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { promisify } from "node:util";
import type { CommandAction, ServiceAction } from "./types";

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

export function expandHome(path: string): string {
  return path === "~"
    ? homedir()
    : path.startsWith("~/")
      ? join(homedir(), path.slice(2))
      : path;
}

async function runCommand(action: CommandAction): Promise<void> {
  try {
    await execFileAsync(action.executable, action.args ?? [], {
      cwd: expandHome(action.cwd),
      env: { ...process.env, PATH: EXEC_PATH },
      timeout: 120_000,
      maxBuffer: 1024 * 1024,
      encoding: "utf8",
    });
  } catch (error) {
    if (typeof error === "object" && error !== null) {
      const detail =
        "stderr" in error && typeof error.stderr === "string"
          ? error.stderr.trim()
          : "";
      if (detail) throw new Error(detail.slice(0, 500));
    }
    throw error;
  }
}

async function runInBackground(action: CommandAction): Promise<void> {
  if (!action.logPath)
    throw new Error("Background action requires a log path.");
  const logPath = expandHome(action.logPath);
  mkdirSync(dirname(logPath), { recursive: true, mode: 0o700 });
  const logFd = openSync(logPath, "a", 0o600);
  try {
    await new Promise<void>((resolve, reject) => {
      const child = spawn(action.executable, action.args ?? [], {
        cwd: expandHome(action.cwd),
        env: { ...process.env, PATH: EXEC_PATH },
        detached: true,
        stdio: ["ignore", logFd, logFd],
      });
      child.once("error", reject);
      child.once("spawn", () => {
        child.unref();
        resolve();
      });
    });
  } finally {
    closeSync(logFd);
  }
}

async function stopListener(
  host: string,
  port: number,
  expectedProcess: string,
): Promise<void> {
  const { stdout } = await execFileAsync(
    "/usr/sbin/lsof",
    ["-nP", "-t", `-iTCP@${host}:${port}`, "-sTCP:LISTEN"],
    { encoding: "utf8", timeout: 5_000 },
  );
  const pids = stdout.trim().split("\n").map(Number).filter(Number.isInteger);
  if (pids.length === 0)
    throw new Error(`Nothing is listening on ${host}:${port}.`);

  for (const pid of pids) {
    const { stdout: command } = await execFileAsync(
      "/bin/ps",
      ["-p", String(pid), "-o", "comm="],
      { encoding: "utf8", timeout: 5_000 },
    );
    if (basename(command.trim()) !== expectedProcess) {
      throw new Error(
        `Refusing to stop unexpected process ${command.trim()} on ${host}:${port}.`,
      );
    }
  }
  for (const pid of pids) process.kill(pid, "SIGTERM");
}

export async function runServiceAction(
  action: ServiceAction,
  operation: "start" | "stop" | "restart",
): Promise<void> {
  switch (action.type) {
    case "command":
      return runCommand(action);
    case "background":
      return runInBackground(action);
    case "homebrew":
      return runCommand({
        type: "command",
        cwd: homedir(),
        executable: "/opt/homebrew/bin/brew",
        args: ["services", operation, action.service],
      });
    case "listener":
      if (operation !== "stop") {
        throw new Error("Listener actions can only stop a service.");
      }
      return stopListener(action.host, action.port, action.process);
  }
}
