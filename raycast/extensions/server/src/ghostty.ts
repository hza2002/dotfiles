import { runAppleScript } from "@raycast/utils";
import { remoteCommand } from "./session.ts";
import type { Host } from "./types.ts";

const SSH_TERM = "xterm-256color";

const SCRIPT = `on run argv
  set hostName to item 1 of argv
  set remoteCommand to item 2 of argv
  set termName to item 3 of argv
  set sshCommand to "/usr/bin/env TERM=" & quoted form of termName & " /usr/bin/ssh -t -- " & quoted form of hostName & " " & quoted form of remoteCommand

  tell application "Ghostty"
    set surfaceConfig to new surface configuration
    set command of surfaceConfig to sshCommand
    set wait after command of surfaceConfig to false
    set serverWindow to new window with configuration surfaceConfig
    activate window serverWindow
  end tell
end run`;

export async function openHost(host: Host): Promise<void> {
  await runAppleScript(SCRIPT, [
    host.alias,
    remoteCommand(host.tmuxSession),
    SSH_TERM,
  ]);
}
