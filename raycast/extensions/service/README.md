# Service

Personal Raycast extension for checking, opening, and managing web services.

The extension reads its private inventory from `~/.config/service/config.json`.
That file owns machine-specific URLs and paths and must not be committed to this
public repository. Use `services.example.json` as the schema reference.

```sh
npm install
npm run dev
npm run build
```

The TypeScript source lives here. `npm run dev` registers or refreshes the local
extension under `~/.config/raycast/extensions/service`; `npm run build` verifies
the production bundle. Stow does not manage that generated runtime copy.
