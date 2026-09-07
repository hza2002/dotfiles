import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";
import type { Entry, MenuNode, Snapshot } from "./model";

const exec = promisify(execFile);

export async function readMenu(
  assetPath: string,
  entry?: Entry,
): Promise<Snapshot> {
  try {
    const { stdout } = await exec(
      "/usr/bin/osascript",
      [
        "-l",
        "JavaScript",
        join(assetPath, "menu.js"),
        ...(entry ? [JSON.stringify(entry.route)] : []),
      ],
      { timeout: 20000, maxBuffer: 1024 * 1024 },
    );
    return {
      version: 1,
      capturedAt: Date.now(),
      nodes: JSON.parse(stdout) as MenuNode[],
    };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Menu operation failed";
    if (message.includes("not running"))
      throw new Error("CC Switch 未运行，请先打开应用。");
    if (
      /not allowed|not authorized|assistive|辅助|权限|-1743|-25211/.test(
        message,
      )
    ) {
      throw new Error("请允许 Raycast 使用辅助功能并控制 System Events。");
    }
    if (message.includes("ambiguous"))
      throw new Error(
        "菜单存在同名项，无法确定目标。请在 CC Switch 中重命名。",
      );
    if (message.includes("changed"))
      throw new Error("菜单已变化，请刷新列表后重试。");
    if (message.includes("disabled"))
      throw new Error("CC Switch 当前禁用了这个选项。");
    if (message.includes("verify"))
      throw new Error("已发送选择，但未确认选中状态。请刷新或检查 CC Switch。");
    throw new Error("无法操作 CC Switch 菜单，请确认应用可响应并刷新后重试。");
  }
}
