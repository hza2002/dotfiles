import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { userInfo } from "node:os";
import { setTimeout as sleep } from "node:timers/promises";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/** Apple Silicon Homebrew first, then Intel, as the repository's launcher does. */
const YABAI_CANDIDATES = ["/opt/homebrew/bin/yabai", "/usr/local/bin/yabai"];
const GHOSTTY_APP = "Ghostty";
const RAYCAST_APP = "Raycast";
const YABAI_TIMEOUT_MS = 3_000;
/** yabai reports a space change about 50 ms after the command returns. */
const FOCUS_TIMEOUT_MS = 1_000;
const WINDOW_TIMEOUT_MS = 2_000;
const POLL_INTERVAL_MS = 50;

interface SpaceState {
  index: number;
  hasFocus: boolean;
  windows: number[];
}

interface ManagedWindow {
  id: number;
  app: string;
  space: number;
}

/** The space a window should open in, plus the windows that predate it. */
export interface ServerSpace {
  index: number;
  /** Ghostty windows open before this command ran, so the new one stands out. */
  ghosttyWindows: Set<number>;
}

let yabaiBinary: string | undefined;

function yabaiPath(): string {
  yabaiBinary ??= YABAI_CANDIDATES.find((candidate) => existsSync(candidate));
  if (yabaiBinary === undefined) {
    throw new Error("yabai is not installed.");
  }
  return yabaiBinary;
}

function failureDetail(error: unknown): string {
  if (typeof error === "object" && error !== null) {
    const stderr: unknown = Reflect.get(error, "stderr");
    if (typeof stderr === "string") {
      const lastLine = stderr.trim().split("\n").at(-1);
      if (lastLine) return lastLine;
    }
  }
  return "yabai command failed.";
}

/**
 * yabai finds its daemon socket through `$USER`, and Raycast's extension host
 * runs without it — yabai then aborts with "'env USER' not set". The OS is the
 * authority on who this is, so it does not matter what the host left out.
 */
export function yabaiEnv(): NodeJS.ProcessEnv {
  return { ...process.env, USER: userInfo().username };
}

async function yabai(...args: string[]): Promise<string> {
  try {
    const { stdout } = await execFileAsync(yabaiPath(), ["-m", ...args], {
      env: yabaiEnv(),
      timeout: YABAI_TIMEOUT_MS,
      maxBuffer: 256 * 1024,
      encoding: "utf8",
    });
    return stdout;
  } catch (error) {
    throw new Error(failureDetail(error));
  }
}

function parseSpaces(output: string): SpaceState[] {
  const spaces = JSON.parse(output) as {
    index: number;
    "has-focus": boolean;
    windows: number[];
  }[];
  return spaces.map((space) => ({
    index: space.index,
    hasFocus: space["has-focus"],
    windows: space.windows,
  }));
}

function parseWindows(output: string): ManagedWindow[] {
  const windows = JSON.parse(output) as {
    id: number;
    app: string;
    space: number;
  }[];
  return windows.map((window) => ({
    id: window.id,
    app: window.app,
    space: window.space,
  }));
}

/**
 * Creating and destroying renumbers every later space, so the created space is
 * whichever index the second snapshot added — never a fixed position.
 */
export function newSpaceIndex(
  before: number[],
  after: number[],
): number | undefined {
  const known = new Set(before);
  const added = after.filter((index) => !known.has(index));
  return added.length === 1 ? added[0] : undefined;
}

/**
 * An empty space usually belongs to a session that has ended, and the window
 * this command opens is exactly what it is waiting for — reusing it costs
 * nothing and keeps the empty space from piling up. `ignore` holds the windows
 * that do not count as occupants, which is the command's own panel: it sits on
 * the space being considered and vanishes as soon as the user looks away.
 */
export function reusableSpace(
  spaces: SpaceState[],
  ignore: Set<number>,
): number | undefined {
  const current = spaces.find((space) => space.hasFocus);
  if (current === undefined) return undefined;

  const occupied = current.windows.filter((id) => !ignore.has(id));
  return occupied.length === 0 ? current.index : undefined;
}

function appWindowIds(windows: ManagedWindow[], app: string): Set<number> {
  return new Set(
    windows.filter((window) => window.app === app).map((window) => window.id),
  );
}

async function focusedSpace(): Promise<number> {
  const space = JSON.parse(await yabai("query", "--spaces", "--space")) as {
    index: number;
  };
  return space.index;
}

async function waitForFocus(index: number): Promise<void> {
  const deadline = Date.now() + FOCUS_TIMEOUT_MS;
  for (;;) {
    if ((await focusedSpace()) === index) return;
    if (Date.now() >= deadline) {
      throw new Error(`Space ${index} never took focus.`);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

async function openedGhosttyWindow(
  before: Set<number>,
): Promise<ManagedWindow | undefined> {
  const deadline = Date.now() + WINDOW_TIMEOUT_MS;
  for (;;) {
    const added = parseWindows(await yabai("query", "--windows")).find(
      (window) => window.app === GHOSTTY_APP && !before.has(window.id),
    );
    if (added !== undefined) return added;
    if (Date.now() >= deadline) return undefined;
    await sleep(POLL_INTERVAL_MS);
  }
}

/**
 * Gives the next window a space of its own: the focused space when nothing
 * occupies it, otherwise a new one created next to it and focused. Throws when
 * yabai cannot be used; the caller degrades to opening in the current space.
 */
export async function createServerSpace(): Promise<ServerSpace> {
  const windows = parseWindows(await yabai("query", "--windows"));
  const ghosttyWindows = appWindowIds(windows, GHOSTTY_APP);
  const before = parseSpaces(await yabai("query", "--spaces"));

  const reuse = reusableSpace(before, appWindowIds(windows, RAYCAST_APP));
  if (reuse !== undefined) {
    return { index: reuse, ghosttyWindows };
  }

  await yabai("space", "--create");
  const created = newSpaceIndex(
    before.map((space) => space.index),
    parseSpaces(await yabai("query", "--spaces")).map((space) => space.index),
  );
  if (created === undefined) {
    throw new Error("yabai did not report the new space.");
  }

  // A new space lands at the end of the display; park it right of the space it
  // was opened from so it stays one step away.
  const origin = before.find((space) => space.hasFocus)?.index;
  let index = created;
  if (origin !== undefined) {
    try {
      await yabai("space", String(created), "--move", String(origin + 1));
      index = origin + 1;
    } catch {
      // Keeping it where it landed beats losing the space it was created in.
    }
  }

  try {
    await yabai("space", "--focus", String(index));
    await waitForFocus(index);
  } catch {
    // Focus is a shortcut, not a requirement: the window is placed explicitly.
  }

  return { index, ghosttyWindows };
}

/**
 * macOS places a window on the space that is active when it is created. If the
 * switch was still animating, the window landed next door — move it back.
 */
export async function ensureWindowLanded(arrival: ServerSpace): Promise<void> {
  const window = await openedGhosttyWindow(arrival.ghosttyWindows);
  if (window === undefined || window.space === arrival.index) return;

  await yabai("window", String(window.id), "--space", String(arrival.index));
}
