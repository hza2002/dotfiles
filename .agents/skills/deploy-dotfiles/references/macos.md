# macOS Deployment Path

Use this path for a personal Apple Silicon Mac. The repository does not promise
Intel Homebrew paths or unattended configuration of macOS security controls.

## Audit the Mac

Collect read-only evidence for:

- macOS release, Apple Silicon architecture, username, home directory, FileVault
  state, disk space, current shell, Xcode Command Line Tools, and Homebrew;
- existing dotfiles, Stow links, Homebrew formulas/casks/taps, applications,
  fonts, LaunchAgents, services, permissions, and conflicting files;
- installed agents and private machine state required by selected modules;
- network access to Homebrew, GitHub, npm, and documented release sources.

Do not assume the username is `ghot`. Generated LaunchAgent paths must come from
the current home directory. Do not import secrets, private inventories, browser
profiles, SSH keys, GnuPG keys, or licensed fonts without explicit user action.

## Confirm Trust and Manual Gates

Read the current README for the exact dependency and module contracts.

- Install Xcode Command Line Tools and official Homebrew before dependent tools.
- Show every non-core tap and its upstream owner, then wait for approval before
  adding it.
- Keep the system `/bin/zsh`; do not install a second Homebrew Zsh.
- Pause for the private `XQzhaopaiti0517` font rather than downloading or storing
  it.
- Explain and pause for Yabai's current partial-SIP Recovery change. Never change
  SIP automatically.
- Pause for Accessibility access to yabai/skhd and Screen Recording access to
  yabai. Do not claim success until the user completes and verifies them.

Treat restart, logout, and reboot requirements as explicit gates, not incidental
installation steps.

## Install the macOS Profile

Install approved Homebrew dependencies and fonts before linking dependent
packages. Use explicit Stow packages rather than linking the whole repository by
default.

For selected modules, preserve this order:

1. Link shared CLI configuration and install its declared plugins/runtime state.
2. Link Automation, then run
   `~/.local/libexec/install-chrome-icon-agent`; register and verify its generated
   LaunchAgent plist.
3. Link Yabai, run `suyabai` only after SIP and permissions are ready, then start
   yabai, skhd, and borders through their documented service commands.
4. Link SketchyBar after its dependencies and fonts, run its
   `install-app-font`, start SketchyBar, and verify both bar and helper.
5. For selected Raycast extensions, install dependencies from each lockfile,
   test and build from repository source, and treat Raycast's installed copy as
   generated output.

Do not run `bing`, `gruvifier`, or `ricon` during bootstrap. Do not create browser
profiles, private Raycast inventories, VPN credentials, icon input directories,
GnuPG keys, or SSH inventories on the user's behalf.

## Verify macOS

Open a fresh terminal and verify:

- `/bin/zsh` is the login shell and starts without cache/version errors;
- Homebrew PATH ordering, linked packages, Bat cache/theme, GnuPG pinentry, tmux,
  Neovim, Yazi, Ghostty, and selected personal utilities;
- the generated Chrome-icon LaunchAgent contains the current home path and is
  registered in the current GUI domain;
- Yabai, skhd, borders, scripting addition, permissions, rules, signals, and
  service restart behavior;
- SketchyBar, its generated icon map, compiled helper, fonts, and Yabai events;
- Raycast extension tests, lint, build, private inventory boundaries, and live
  integration for selected extensions;
- `./check` completes without rewriting tracked files.

Report any permission, SIP, private-font, sign-in, or GUI action still awaiting
the user as incomplete rather than silently skipping it.
