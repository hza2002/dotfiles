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

Provider selections come from the native menu. Nested project selections
retain their menu groups. Lightweight mode is shown as a read-only global state.
It stays in the bottom Global section across application filters and is not an
application dropdown option. Native text search still filters matching rows.

Official OpenAI providers in the Codex group also show the signed-in GPT account's
remaining five-hour and weekly quotas, available reset credits, reset-credit details
and expiry times, local reset times, countdowns, plan type, and fetch time. Quotas refresh when opening the command, refreshing the
menu, or switching providers. Command-Shift-R refreshes quotas independently of
the native menu.
Countdowns update every 30 seconds; reaching a reset time requires a fresh query.
Quota results remain in memory and are not persisted.

The quota detail separates the five-hour and weekly windows and lists every reset
credit returned by Codex, including status and expiry. Dates use the current system
timezone and `YYYY-MM-DD HH:mm` (24-hour time); the timezone is displayed with the
account and update time below the quotas. When available, the provider row includes
compact 5h, 7d, and Reset accessories; low remaining quota is colored orange or red.

This optional display reads the default `~/.cc-switch/cc-switch.db` in read-only
mode to identify uniquely named Codex providers classified as `official` and
their saved ChatGPT account IDs. It verifies the account against
`~/.codex/auth.json`, then uses the Homebrew Codex CLI at
`/opt/homebrew/bin/codex` and its official `account/rateLimits/read` RPC. The
short-lived process overrides the provider and ChatGPT service URL for its own
query; it does not switch providers or rewrite tracked configuration. Codex owns
authentication and any normal credential refresh. No conversation is started.

An official provider can be inactive, but its saved account must match the local
GPT login. API-key login, unmatched accounts, absent windows, and query failures
are shown explicitly. Third-party providers do not receive a quota display.
Menu-based switching remains available when quota discovery or querying fails.

Requires macOS, Raycast, a running CC Switch with a menu bar icon, and Raycast
permission to use Accessibility and control System Events. Menu operations use
the macOS-provided `osascript`. Quota queries additionally require the Homebrew
Codex CLI; no persistent background server is required.

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
