# Dotfiles

Personal configuration for initializing a new Apple Silicon Mac, Ubuntu or
Debian host, or WSL2 environment. The repository is an initializer, not a
continuous multi-host synchronization system.

Configuration packages are laid out for GNU Stow. An idempotent bootstrap
program will install their dependencies, check for conflicts, and link the
selected packages. Stow runs from the repository root, where `.stowrc` disables
tree folding so tools cannot write runtime data back through a linked directory.

## Zsh

The Zsh package targets Zsh 5.9 or newer on macOS and Linux.

- [`.zshenv`](zsh/.zshenv) contains the small environment shared by every Zsh
  invocation.
- [`.zprofile`](zsh/.zprofile) initializes the login environment and `PATH`.
- [`.zshrc`](zsh/.zshrc) owns interactive behavior, plugins, aliases, key
  bindings, and platform-specific integrations.
- [`.config/fzf`](zsh/.config/fzf) contains the fzf shell integration and
  preview script.

Read these files for the current behavior. Plugin names, aliases, key bindings,
and optional tool paths are intentionally not duplicated here.

The bootstrap installation contract for this package is:

- use Homebrew on macOS and apt on Ubuntu or Debian;
- install incompatible or unavailable Linux tools from pinned upstream releases
  under `~/.local`, with commands exposed through `~/.local/bin`;
- install Oh My Zsh and its custom plugins from their upstream Git repositories;
- install Jenv, a default JDK, Gradle, Maven, Ant, and Miniconda;
- stop for user input instead of replacing an unknown existing installation.

The future bootstrap catalog will be the source of truth for package providers,
versions, release assets, and checksums. The macOS sandbox helpers remain
configuration-only and are not part of the bootstrap contract.

## Bat

The Bat package keeps the custom Gruvbox Material theme used by the shell and
file previews. Use Homebrew on macOS and apt on Ubuntu 24.04 or newer. Ubuntu's
package may expose only `batcat`; when `bat` is absent, the bootstrap must link
`~/.local/bin/bat` to the installed `batcat` executable.

After linking the package, run `bat cache --build` and verify that
`gruvbox-material-dark` appears in `bat --list-themes`. The generated cache is
runtime data and must not be stored in this repository.

## tmux

The tmux package targets tmux 3.4 or newer. [`tmux.conf`](tmux/.config/tmux/tmux.conf)
contains the configuration, while
[`agent-sidebar.sh`](tmux/.config/tmux/scripts/agent-sidebar.sh) contains the small
amount of local behavior layered on the upstream sidebar plugin. Read those
files for the current bindings and plugin settings.

Copy mode targets the clipboard of the attached terminal client through OSC 52,
including through SSH and nested tmux sessions. Unsupported terminal clients
still retain the selection in tmux's paste buffer.

The bootstrap installation contract for this package is to install tmux, TPM,
the plugins declared in `tmux.conf`, sesh, and fzf, then configure sidebar hooks
for installed agents. Macism is required only on macOS. Clipboard integration
does not require platform-specific packages; terminal clients must permit OSC 52
writes.

## Yazi

The Yazi package targets Yazi 26.5.6 or newer on macOS and Linux. The five
tracked files under [`yazi/.config/yazi`](yazi/.config/yazi) are configuration
source; plugins and flavors are generated runtime data and must not be stored in
the repository.

The bootstrap installation contract is to use Homebrew on macOS and Yazi's
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

The bootstrap installation contract is to install the base command-line
dependencies, link the package, synchronize the revisions pinned in
[`lazy-lock.json`](nvim/.config/nvim/lazy-lock.json), and wait for all Mason
packages to finish installing. Plugin and tool installation must complete before
the module is reported as installed rather than being deferred to first launch.

## Ghostty and Raycast

Ghostty is the macOS terminal client and starts the `Main` tmux session directly.
Its bootstrap contract is Ghostty 1.3 or newer and the Homebrew cask
`font-jetbrains-maple-mono`. Read [`config`](ghostty/.config/ghostty/config) for
the current terminal behavior and tmux key translations.

Raycast extensions are maintained as source under [`raycast/extensions`](raycast/extensions).
The Servers extension reads SSH aliases from the private inventory at
`~/.config/server/config.json` and attaches each selected host to its `main` tmux
session. Host addresses, users, ports, and keys remain in `~/.ssh/config` and are
not owned by this repository.
