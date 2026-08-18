import { runAppleScript } from "@raycast/utils";
import type { ServerConfig } from "./types";

const SESSION_NAME = "main";
const SSH_TERM = "xterm-256color";

export async function openServer(server: ServerConfig): Promise<void> {
  await runAppleScript(
    `on run argv
      set hostName to item 1 of argv
      set sessionName to item 2 of argv
      set termName to item 3 of argv
      set remoteCommand to "exec tmux new-session -A -s " & quoted form of sessionName
      set sshCommand to "/usr/bin/env TERM=" & quoted form of termName & " /usr/bin/ssh -t -- " & quoted form of hostName & " " & quoted form of remoteCommand

      tell application "Ghostty"
        set surfaceConfig to new surface configuration
        set command of surfaceConfig to sshCommand
        set wait after command of surfaceConfig to false
        set serverWindow to new window with configuration surfaceConfig
        activate window serverWindow
      end tell
    end run`,
    [server.host, SESSION_NAME, SSH_TERM],
  );
}
