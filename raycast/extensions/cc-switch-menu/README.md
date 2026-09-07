# CC Switch for Raycast

A local Raycast extension backed by the installed CC Switch menu. It discovers
application groups and nested selections without a fixed app or provider list.
The menu controls ordering, availability and selected state. Top-level commands
such as Quit are excluded from provider actions; disabled empty groups remain visible.

Search for `CC Switch Providers` in Raycast. Select an application using the dropdown, search
menu options, and press Enter to select. Command-R refreshes the
menu; Command-O opens CC Switch. The application filter is remembered.

Menu snapshots are cached locally. Opening a cached list, filtering and searching
do not access the menu. The displayed selection is from the timestamped snapshot;
refresh after making changes elsewhere. Initial discovery, refresh and selection
temporarily open the native menu. Selection resolves the route against the live
menu and rejects ambiguous or unavailable targets. Confirmation waits for the
target to be the only checked sibling and, for providers, for the group title to
name the target. The native checkbox's immediate toggle is not proof of success.
Transient menu rebuilds are retried; an unconfirmed selection is reported as such
and does not replace the cache. This verifies menu state, not provider connectivity.
Selecting a cached active target refreshes the menu without sending a selection.

All displayed information comes from the native menu. Nested project selections
retain their menu groups. Lightweight mode is shown as a read-only global state.
No provider database, configuration, or API is accessed.

Requires macOS, Raycast, a running CC Switch with a menu bar icon, and Raycast
permission to use Accessibility and control System Events. Uses the macOS-provided
`osascript`; no CLI fork or background server is required.

## Development

Source is maintained in `~/dotfiles/raycast/extensions/cc-switch-menu`.
`npm run dev` registers or refreshes the runtime copy under
`~/.config/raycast/extensions/cc-switch-menu`; Stow does not manage that copy.
Dependencies, generated type definitions and menu snapshots are not tracked.
The repository's `./check` includes this extension's tests and type checks.

```sh
npm ci
npm test
npm run lint
npm run build
npm run dev
```

Verify in Raycast: all menu groups and providers appear in order; search and app
filter work; the filter persists on reopening; current selection is verified;
unavailable or duplicate targets cannot be selected; errors preserve the cached
list; refreshing reflects menu changes. Future structural changes to CC Switch's
menu may require adapting `assets/menu.js`.

Removing this local extension from Raycast leaves CC Switch's data intact.

The extension icon is taken from the locally installed CC Switch application.
