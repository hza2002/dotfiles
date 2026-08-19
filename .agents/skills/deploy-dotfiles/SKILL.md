---
name: deploy-dotfiles
description: Plan and execute an end-to-end deployment of this dotfiles repository to a new or existing Apple Silicon macOS workstation, Ubuntu or Debian host, or WSL2 environment. Use when the user asks to initialize, bootstrap, migrate, or resume a complete machine setup. Do not use for isolated package, shell, SSH, tmux, editor, proxy, or dotfiles questions.
---

# Deploy Dotfiles

Deploy the repository as a consumer of its tracked configuration. Discover the
target first, agree on the complete contract, then install dependencies, link
selected Stow packages, perform approved machine setup, and verify the result.

## Select the Platform Path

1. Read the repository `AGENTS.md`, `README.md`, `.stowrc`, and current Git
   status.
2. Inspect the target operating system and architecture without changing it.
3. Read the matching reference completely before planning:
   - Apple Silicon macOS workstation: [references/macos.md](references/macos.md)
   - Ubuntu, Debian, or WSL2: [references/linux.md](references/linux.md)
4. Read both references only when one request covers both platform families.
5. For an unsupported platform or architecture, finish discovery and ask before
   extending the deployment contract.

## Preserve the Boundary

- Treat tracked dotfiles as configuration source, not bootstrap output.
- Never rewrite tracked configuration to make one machine pass. Keep necessary
  host-specific changes as explicit machine state or a reviewable downstream
  patch.
- Keep credentials, private keys, inventories, fonts, caches, generated files,
  histories, and application state out of Git.
- Preserve unrelated local and remote changes. Do not replace an existing file,
  account, service, or symlink without resolving it and defining rollback.
- Prefer simple, idempotent operations. Detect completed work before repeating
  installs, downloads, links, service registration, or manual steps.
- Do not commit or push unless the user explicitly asks.
- Do not run broad upgrades, automatic cleanup, reboot, or destructive removal
  as an incidental deployment step.

## Phase 1: Discover

Inspect the repository and target read-only. Resolve:

- target identity, OS, architecture, hostname, home directory, login shell, and
  whether the machine is shared;
- current access, privilege boundaries, package managers, proxies, disk space,
  and network access to required upstreams;
- existing dotfiles, repositories, symlinks, shell startup files, applications,
  services, plugins, private state, and conflicting commands;
- selected workstation, server, or WSL profile and packages explicitly excluded;
- platform-specific security and manual gates from the selected reference.

Use current source and runtime state as evidence. When the README, skill, and
machine disagree, report the drift before planning.

## Phase 2: Agree on the Contract

Present two flat lists headed `Will do` and `Will not do`. Include, as applicable:

- exact target and selected Stow packages;
- system-wide and user-local dependencies, their provider, version policy, and
  trust boundary;
- files or links to create or replace, conflicts, backups, and rollback;
- accounts, authentication, sudo, permissions, services, and restarts;
- private or manual state the user must supply;
- verification steps and known residual risks.

Wait for approval of the complete contract. Before any later privileged,
security-sensitive, authentication, or conflicting-file change not already
shown exactly, stop and obtain focused approval.

## Phase 3: Deploy

After approval:

1. Establish prerequisites and access without weakening existing security.
2. Install only approved dependencies from the agreed providers.
3. Complete or pause at platform manual gates before dependent modules.
4. Back up approved conflicts and record exact restoration commands.
5. Run GNU Stow from the repository root for explicit packages only. Preserve
   `.stowrc` no-folding behavior.
6. Run the module-owned installers documented in `README.md`; do not reproduce
   their implementation in deployment commands.
7. Register or restart only approved user services.
8. Leave risky personal utilities and private-state initialization as explicit
   user actions unless the contract specifically includes them.

Keep the active access path open while changing shells, authentication, window
management, or services.

## Phase 4: Verify and Report

Verify through the way the user will actually work: a fresh terminal or SSH
login, the configured shell, linked paths, selected tools, services, and module
behavior. Run `./check` after its declared dependencies are installed. Do not
treat command presence or configuration parsing alone as full success.

Report:

- local and target changes;
- installed system and user dependencies with sources;
- linked packages, generated runtime files, and private/manual state left out;
- backups and exact rollback paths;
- tests performed, failures, skipped external checks, and pending restarts;
- safe steps for applying future dotfiles updates.

Do not claim completion while required installs, manual gates, service checks,
or verification commands remain unfinished.
