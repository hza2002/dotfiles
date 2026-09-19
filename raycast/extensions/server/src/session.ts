function quote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

/**
 * The command the remote shell runs. Hosts without tmux get a login shell
 * instead of a window that closes immediately.
 */
export function remoteCommand(tmuxSession: string): string {
  return (
    "if command -v tmux >/dev/null 2>&1; " +
    `then exec tmux new-session -A -s ${quote(tmuxSession)}; ` +
    'else exec "${SHELL:-/bin/sh}" -l; fi'
  );
}
