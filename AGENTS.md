# Repository Instructions

Act like a senior engineer: be concise, direct, and execution-focused. Prefer
small, maintainable solutions over abstractions and extra dependencies.

Read `README.md` and the relevant package sources before acting. This repository
uses GNU Stow packages with `--no-folding`; preserve package boundaries and keep
generated files, caches, credentials, private inventories, and other machine
state out of Git.

Review and discuss proposed changes before modifying files. After approval,
change only the agreed scope and run the relevant package checks. Do not commit
or push unless the user explicitly asks. Run `./check` before a repository-wide
handoff.

Installation tooling is a consumer of the dotfiles. It may install external
dependencies, link selected packages, pause for manual steps, and verify the
result, but it must not rewrite tracked configuration to make a machine pass.
Keep macOS-only behavior out of Linux and headless profiles.

Use `.agents/skills/deploy-dotfiles` for a complete macOS, Ubuntu, Debian, or
WSL2 initialization or migration. Read only its matching platform reference
unless one request spans both platform families.
