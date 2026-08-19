# Server

Personal Raycast extension for opening SSH servers in Ghostty and attaching to
the `main` tmux session.

The extension reads its private inventory from `~/.config/server/config.json`.
Each `host` is an alias resolved by `~/.ssh/config`; addresses, users, ports, and
keys remain outside this repository. Use `servers.example.json` as the schema
reference.

```sh
npm install
npm run dev
npm run build
```

The TypeScript source lives here. `npm run dev` registers or refreshes the local
extension under `~/.config/raycast/extensions/server`; `npm run build` verifies
the production bundle. Stow does not manage that generated runtime copy.
