# VPN

Personal Raycast extension for Clash routing and the Work and School VPNs
managed by `~/.local/bin/via`.

```sh
npm install
npm run dev
npm run build
```

The TypeScript source lives here. `npm run dev` registers or refreshes the local
extension under `~/.config/raycast/extensions/network-control`; `npm run build`
verifies the production bundle. Stow does not manage that generated runtime
copy.
