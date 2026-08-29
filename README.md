# Dotfiles

Personal configuration for initializing a new Apple Silicon Mac, Ubuntu or
Debian host, or WSL2 environment. The repository initializes machines; it is not
a continuous multi-host synchronization system.

## Deployment Model

Complete machine setup is agent-assisted. The tracked `deploy-dotfiles` skill
audits the target, follows the installation contracts in this README, links
explicit GNU Stow packages, and verifies the result. The repository deliberately
does not provide or maintain a standalone bootstrap program.

Tracked dotfiles remain configuration source. Module-owned installers handle
the few operations that need deterministic local behavior, while `./check`
provides the repository-wide validation gate. Stow runs from the repository
root, where `.stowrc` disables tree folding so tools cannot write runtime data
back through a linked directory.

## Getting Started

Clone the repository, enter it, and start an agent that supports repository
skills:

```bash
git clone https://github.com/hza2002/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Ask the agent to use `$deploy-dotfiles` to initialize the machine. It presents
the applicable deployment contract and waits for approval before changing the
system. Git and a repository-skill-aware agent are the only entry-point
requirements; the skill handles platform-specific requirements and resumable
deployment.

## Zsh

The Zsh package targets Zsh 5.9 or newer on macOS and Linux. macOS uses the
system `/bin/zsh`; installing a second Homebrew Zsh is unnecessary.

- [`.zshenv`](zsh/.zshenv) contains the small environment shared by every Zsh
  invocation.
- [`.zprofile`](zsh/.zprofile) initializes the login environment and `PATH`.
- [`.zshrc`](zsh/.zshrc) owns interactive behavior, plugins, aliases, key
  bindings, and platform-specific integrations.
- [`.config/fzf`](zsh/.config/fzf) contains the fzf shell integration and
  preview script.

Read these files for the current behavior. Plugin names, aliases, key bindings,
and optional tool paths are intentionally not duplicated here.

The deployment contract for this package is:

- use the system Zsh and Homebrew dependencies on macOS, and apt on Ubuntu or
  Debian;
- install Eza as the interactive `ls` replacement;
- install incompatible or unavailable Linux tools from pinned upstream releases
  under `~/.local`, with commands exposed through `~/.local/bin`;
- install [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) and the custom plugins
  below by following each upstream repository's current installation and update
  instructions;
- install Jenv, a default JDK, Gradle, Maven, Ant, and Miniconda;
- stop for user input instead of replacing an unknown existing installation.

| Plugin | Upstream repository |
| --- | --- |
| `autoupdate` | `https://github.com/TamCore/autoupdate-oh-my-zsh-plugins` |
| `fzf-tab` | `https://github.com/Aloxaf/fzf-tab` |
| `you-should-use` | `https://github.com/MichaelAquilina/zsh-you-should-use` |
| `zsh-abbr` | `https://github.com/olets/zsh-abbr` |
| `zsh-autosuggestions` | `https://github.com/zsh-users/zsh-autosuggestions` |
| `zsh-completions` | `https://github.com/zsh-users/zsh-completions` |
| `zsh-history-substring-search` | `https://github.com/zsh-users/zsh-history-substring-search` |
| `zsh-lazyload` | `https://github.com/qoomon/zsh-lazyload` |
| `zsh-syntax-highlighting` | `https://github.com/zsh-users/zsh-syntax-highlighting` |
| `zsh-vi-mode` | `https://github.com/jeffreytse/zsh-vi-mode` |

These repositories currently follow their upstream default branches; the
dotfiles do not pin their commits. [`.zshrc`](zsh/.zshrc) remains the source of
truth for which plugins are enabled.

## Bat

The Bat package keeps the custom Gruvbox Material theme used by the shell and
file previews. Use Homebrew on macOS and apt on Ubuntu 24.04 or newer. Ubuntu's
package may expose only `batcat`; when `bat` is absent, deployment must link
`~/.local/bin/bat` to the installed `batcat` executable.

After linking the package, run `bat cache --build` and verify that
`gruvbox-material-dark` appears in `bat --list-themes`. The generated cache is
runtime data and must not be stored in this repository.

## GnuPG

The GnuPG package configures pinentry for signed Git commits. It uses the native
macOS prompt in a regular local shell and the terminal prompt in tmux, over SSH,
and on Linux or WSL. Install GnuPG plus `pinentry-mac` on macOS, or GnuPG plus
`pinentry-curses` on Ubuntu or Debian.

Before linking the package, create `~/.gnupg` with mode `0700`. After linking,
restart the agent with `gpgconf --kill gpg-agent` and verify a signed commit or
equivalent signing operation. Private keys, trust data, and the selected Git
signing key are machine state and must not be stored in this repository.

## tmux

The tmux package targets tmux 3.4 or newer. [`tmux.conf`](tmux/.config/tmux/tmux.conf)
contains the configuration. The scripts directory contains the local behavior
layered on the upstream sidebar plugin and the Ghostty-only cursor reveal used
when selecting panes whose applications hide the cursor. Read those files for
the current bindings and plugin settings.

The sidebar uses `hza2002/tmux-agent-sidebar`, a focused fork that keeps the
localized desktop notification behavior and syncs upstream daily. Conflict-free
updates are tested and released automatically; conflicts require manual review.

Copy mode targets the clipboard of the attached terminal client through OSC 52,
including through SSH and nested tmux sessions. Unsupported terminal clients
still retain the selection in tmux's paste buffer.

The deployment contract for this package is to install tmux, TPM,
the plugins declared in `tmux.conf`, sesh, and fzf, then configure sidebar hooks
for installed agents. Macism is required only on macOS. Clipboard integration
does not require platform-specific packages; terminal clients must permit OSC 52
writes.

## Yazi

The Yazi package targets Yazi 26.5.6 or newer on macOS and Linux. The five
tracked files under [`yazi/.config/yazi`](yazi/.config/yazi) are configuration
source; plugins and flavors are generated runtime data and must not be stored in
the repository.

The deployment contract is to use Homebrew on macOS and Yazi's
official signed stable APT repository on Ubuntu or Debian. Install the complete
integration set: file, Git, Starship, Lazygit, Ouch, FFmpeg, 7-Zip, jq, Poppler,
fd, ripgrep, fzf 0.53 or newer, zoxide, resvg, and ImageMagick 7.1.1 or newer.
After Stow links the package, run `ya pkg install` to install the revisions and
hashes pinned in [`package.toml`](yazi/.config/yazi/package.toml). Linux desktop
systems additionally need a supported clipboard helper; headless hosts do not.

## Neovim

The Neovim package targets Neovim 0.12 or newer. Use Homebrew on macOS and
Neovim's official stable release archive under `~/.local` on Linux or WSL; do
not use the Ubuntu or Debian package. [`lazyvim.json`](nvim/.config/nvim/lazyvim.json)
and the files under [`lua/plugins`](nvim/.config/nvim/lua/plugins) are the source
of truth for enabled language support and external toolchains.

The deployment contract is to install the base command-line
dependencies, link the package, synchronize the revisions pinned in
[`lazy-lock.json`](nvim/.config/nvim/lazy-lock.json), and wait for all Mason
packages to finish installing. Plugin and tool installation must complete before
the module is reported as installed rather than being deferred to first launch.

## macOS Personal Utilities

The Automation, Bin, and IdeaVim packages are installed only on a personal
macOS workstation. Deployment must skip them on Linux, WSL, and headless hosts.
They require the Homebrew formulas `uv` and `fileicon`; the casks
`google-chrome`, `microsoft-edge`, and `jetbrains-toolbox`; and the
`bing-rewards` uv tool. `gruvifier` resolves `gruvbox-factory@latest` through
`uvx` when explicitly run.

Before `bing` can run, the Edge profiles `Default` and `Profile 2` must exist,
be signed in to Bing, and the private `~/.config/bing-rewards/config.json` must
select Edge as its browser. The directories `~/Pictures/icons` and
`~/Pictures/unreviewed` are also user-owned machine state. Deployment must not
create, populate, or store any of these files in Git.

After linking Automation, run
`~/.local/libexec/install-chrome-icon-agent` to render the current home directory
into `~/Library/LaunchAgents/com.ghot.chrome-custom-icon.plist`. Register that
generated plist in the current GUI domain and verify the LaunchAgent. The
generated plist is machine state and is not stored in Git. After installing the
selected JetBrains IDEs, install the `IdeaVIM` and `IdeaVimExtension` plugins in
each IDE, link IdeaVim, and reload `.ideavimrc`.

Deployment installs these commands but never runs `bing`, `gruvifier`, or
`ricon`. They respectively control Edge, modify images, and request elevated
access to change application icons, so each remains an explicit user action.

## Yabai

The Yabai package configures the macOS window-management stack. Deployment
requires the Homebrew formulas `asmvik/formulae/yabai`,
`asmvik/formulae/skhd`, `felixkratz/formulae/borders`, and `jq`. The qualified
formulas come from two non-core upstream maintainer taps; the agent must show
their sources and ask before adding them.

Grant Accessibility access to yabai and skhd, and Screen Recording access to
yabai. The scripting addition also requires manually configuring the partial
SIP mode documented for the installed yabai release from macOS Recovery.
Deployment must pause for this step and must not attempt to change SIP.

After linking the Yabai package, run `suyabai` to install the validated,
hash-bound sudoers rule and load the scripting addition. Run it again whenever
Homebrew upgrades yabai; no shell update command calls it automatically. Start
the daemons with `yabai --start-service`, `skhd --start-service`, and
`brew services start borders`.
Apply later configuration changes with
`yabai --restart-service`, `skhd --restart-service`, and
`brew services restart borders` rather than executing `yabairc` directly, which
would append duplicate rules and signals to the running process.

## SketchyBar

The SketchyBar package is a macOS-only desktop module built around the configured
Yabai module and SketchyBar. Read the files under
[`sketchybar/.config/sketchybar`](sketchybar/.config/sketchybar) for its current
behavior.

Deployment requires Xcode Command Line Tools; the Homebrew formulas
`felixkratz/formulae/sketchybar`, `jq`, `switchaudio-osx`, and `fastfetch`; and
the casks `font-jetbrains-maple-mono` and `swiftdialog`. The qualified formula
comes from a non-core upstream maintainer tap; the agent must show its source
and ask before adding it. The private `XQzhaopaiti0517` font must be installed
manually. Deployment pauses when it is missing.

After installing dependencies and fonts, link the package with Stow, run
[`scripts/install-app-font`](sketchybar/.config/sketchybar/scripts/install-app-font),
start SketchyBar, and verify the bar and helper processes. The installer fetches
`sketchybar-app-font` and generates `plugins/icon_map.sh`. The compiled helper
and generated icon map are runtime files and are not stored in Git.

## Ghostty and Raycast

Ghostty is the macOS terminal client and starts the `main` tmux session in
`~/repo/scratch`, leaving `~/repo` as the project overview.
Its deployment contract is Ghostty 1.3 or newer and the Homebrew cask
`font-jetbrains-maple-mono`. Read [`config`](ghostty/.config/ghostty/config) for
the current terminal behavior and tmux key translations. The tracked cursor
shaders are configuration source; the derived smear shader retains its upstream
source revision and MIT notice in the file header.

Raycast extensions are maintained as source under [`raycast/extensions`](raycast/extensions).
The Server extension reads SSH aliases from the private inventory at
`~/.config/server/config.json` and attaches each selected host to its `main` tmux
session. Host addresses, users, ports, and keys remain in `~/.ssh/config` and are
not owned by this repository.

## Validation

Run `./check` from the repository root after changing the dotfiles. It performs
read-only Stow, syntax, configuration, and module test gates. Platform-specific
runtime checks run only on their supported operating system. The command does
not install dependencies, update plugins, or rewrite tracked configuration.
