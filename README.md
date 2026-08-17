# Dotfiles

Personal configuration for initializing a new Apple Silicon Mac, Ubuntu or
Debian host, or WSL2 environment. The repository is an initializer, not a
continuous multi-host synchronization system.

Configuration packages are laid out for GNU Stow. An idempotent bootstrap
program will install their dependencies, check for conflicts, and link the
selected packages.

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
