# Linux Deployment Path

Use this path for Ubuntu, Debian, and WSL2. Treat a remote server as potentially
shared until discovery proves otherwise.

## Audit the Target

Collect read-only evidence for:

- distribution, release, architecture, kernel, WSL status, hostname, timezone,
  disk, memory, and current shell;
- login identity, home ownership, groups, sudo capability, active sessions, and
  whether sudo requires a password;
- SSH authentication, authorized-key modes, password-login policy, keepalives,
  and a second usable access path;
- installed packages, user-local binaries, package sources, existing dotfiles,
  shell plugins, Neovim state, tmux sessions, and conflicts;
- outbound access to package and Git hosts and any approved proxy.

Do not expose other users' files, password hashes, private keys, tokens, shell
history, or credentials. For distributions outside Ubuntu or Debian, stop after
the audit and ask before adapting package management.

## Confirm Access and Privilege

The deployment contract must state the account, home, login shell, SSH-key and
password-login policy, sudo policy, and whether system-wide effects are allowed.

When account, SSH, sudoers, or daemon changes are approved:

1. Show the exact change and rollback first.
2. Keep the current administrative session open.
3. Install public keys only; never copy a private key.
4. Verify a fresh second SSH login and sudo behavior before continuing.

Do not default to unrestricted passwordless sudo on a shared server.

## Install the Linux Profile

Read the current README contracts before selecting providers. The normal
headless profile is `bat gnupg nvim tmux yazi zsh`; do not deploy macOS-only,
GUI-only, Automation, Bin, IdeaVim, Raycast, Yabai, SketchyBar, or Ghostty
packages to a server.

- Use `apt` for approved stable system dependencies.
- Use the official signed Yazi APT repository described by the current upstream.
- Install Neovim's official stable release under `~/.local`; do not use the
  older Ubuntu or Debian package.
- Use pinned upstream release artifacts under `~/.local` when the repository
  contract rejects or cannot obtain a distribution package.
- Keep shell plugins, editor plugins, caches, and application state user-local.
- Install SDKs, runtimes, databases, containers, agents, and GPU tooling only
  when explicitly included.

Run `apt update` only when needed for an approved transaction. Show the exact
system package transaction before installing it. Do not incidentally run
`apt upgrade`, `apt autoremove`, restart unrelated services, or reboot.

## Deploy Without Forking the Workstation Config

- Back up conflicting user files with ownership and modes preserved.
- Keep existing Bash startup files unless replacement is explicitly approved.
- Change the login shell only after a fresh Zsh startup succeeds.
- Apply server-specific requirements as a visible downstream patch or machine
  state; do not add a global environment flag or disable shared configuration
  merely to satisfy one host.
- Configure a stable host-reachable proxy when needed. Do not hard-code a
  transient container address.

## Verify Linux

Use a fresh SSH login or WSL session and verify:

- identity, home ownership, shell, SSH, and approved sudo behavior;
- login and interactive Zsh startup without errors;
- PATH ordering and actual command resolution;
- Stow targets and any server-local diff;
- GnuPG terminal pinentry, tmux start/detach/reattach, Neovim plugin/tool
  completion, Yazi plugins, Bat theme/cache, and trash behavior;
- proxy name resolution and an end-to-end request when proxying is included;
- a second SSH connection remains possible.

Report pending service restarts or reboot notices without acting on them.
