# Server

Personal Raycast extension for opening SSH hosts in Ghostty. Hosts are
discovered from `~/.ssh/config` on every launch: literal `Host` patterns become
list entries, wildcard and `Match` blocks are ignored, and `Include` files are
followed in place. There is no inventory to maintain.

Each alias is resolved with `ssh -G`, so the list shows the effective
`user@hostname:port` without reimplementing SSH configuration semantics. Hosts
whose effective user is `git` are hidden, and aliases that resolve to the same
target collapse into a single entry.

Write your own annotation for a host as a comment in `~/.ssh/config`: either the
comment block directly above its `Host` line, or a trailing comment on the line
itself, which wins. The annotation replaces the target in the list, while the
target stays in the detail pane. A blank line or any other directive ends the
block, commented-out directives are never mistaken for a note, and a note is cut
at 160 characters. OpenSSH rejects unknown keywords outright (`Bad configuration
option`), so a dedicated `Note` field cannot exist — comments are the only
channel.

The list is ordered by most recent connection. Terminal connections are read
from the timestamps in `~/.zsh_history`; connections opened by this extension
are recorded in Raycast LocalStorage, because a window the extension opens
never reaches the shell history. Hosts that were never used keep their
`~/.ssh/config` order. Opening a host attaches to its tmux session when the
remote has tmux, and falls back to a login shell when it does not.

Opening also gives the window a space of its own: the focused space when nothing
occupies it yet — normally the one the previous session left behind — and
otherwise a space yabai creates directly right of the focused one, which is then
focused. Raycast's own panel does not count as an occupant: it is open on the
space being considered and leaves with the command. Either way a server session
never displaces what is already on screen. `Open in Current Space` opens
where the command was invoked instead. Without yabai, or with the scripting
addition unloaded, the open degrades to the current space and says so, because a
window in the wrong place beats a host that cannot be reached. Nothing here ever
destroys a space, so an empty one stays until you remove it yourself.

The created space is identified by comparing the space list before and after the
create, because every create and destroy renumbers the spaces that follow. macOS
places a window on the space that is active when it appears — normally the one
just focused, but a space switch still animating can lose that race — so the
window list is read once after opening and the window is moved back if it landed
next door. That check runs after Raycast closes, so it costs the open nothing
visible.

The list stays minimal: an alias and its note. Everything else lives in the
detail pane — the note, target, address, location, identity file, host key, the
options this host actually changes, last connection, the last measured latency,
and the tmux session, in a label/value grid. That split is deliberate: Raycast
renders titles in a proportional font and exposes no column widths, so a list
column after a variable-length title cannot line up at all, while the metadata
grid is genuinely aligned. The pane is opened with `isShowingDetail`, which is
required for `List.Item.Detail` to render.

Identity files and effective options reuse the `ssh -G` output the list already
needs. Options are compared against a name no `Host` block matches, which
resolves to plain OpenSSH defaults plus your `Host *` block — so only what the
host itself changes survives, and settings already shown as their own row
(target, identity file, known-hosts files) never repeat. Option rows keep the
lowercase names `ssh -G` prints, so they match what a terminal shows. Host keys
are looked up locally with `ssh-keygen -F`, which handles hashed `known_hosts`
files and opens no connection.

Addresses and locations are looked up for the selected host only, so opening
the command makes no request at all. Addresses come from Cloudflare
DNS-over-HTTPS and locations from ipwho.is; both are cached in Raycast
LocalStorage — an hour for addresses, thirty days for locations. Locations are
keyed by address, so two aliases pointing at one machine share a single lookup.
Private addresses are marked 🏠 and never looked up. A cold host resolves in
about a second, and `Refresh IP and Location` forces a refetch.

`~/.config/server/config.json` is an optional overlay that is never required:
a missing, empty, or unreadable file is ignored, and a broken one degrades to a
toast while the list keeps working. It can only exclude hosts, include hidden
ones, rename them, or pick a different tmux session. Use `config.example.json`
as the schema reference.

Checking the complete non-interactive SSH connection still runs only when
asked, and its result lasts until the Raycast command closes. Nothing is ever
written back to `~/.ssh/config`.

```sh
npm install
npm run dev
npm run build
```

The TypeScript source lives here. `npm run dev` registers or refreshes the local
extension under `~/.config/raycast/extensions/server` and keeps watching;
`npm run build` writes the same bundle once. Both deploy it, because that
directory is where Raycast loads a development extension from — `./check raycast
server` builds into a temporary directory instead, so checking never deploys.
Stow does not manage that generated runtime copy.
