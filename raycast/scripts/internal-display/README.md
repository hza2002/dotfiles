# Internal Display

A personal Apple Silicon display controller with a Raycast Script Command
entry point. The Swift core owns event monitoring, private display APIs, mode
persistence, and a local Unix socket. Raycast only calls `toggle`; it does not
poll or keep the background service alive. Unsupported macOS APIs are derived
in part from Clamless; see [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

## Project Files

- `main.swift`: background controller and command-line interface.
- `tests.swift`: policy tests and opt-in display tests.
- `manage.sh`: build, install, link, start, and uninstall.
- `toggle-internal-display.sh` and `internal-display.png`: Raycast entry point.

All maintained files live here. Stow ignores `raycast/scripts`;
`manage.sh` owns deployment. Run it directly from this directory, or by its
repository path. It resolves source files relative to itself.

## Installation

Run `./manage.sh install` with Xcode Command Line Tools installed. It compiles
the core into `~/.local/libexec/display-control`, generates the LaunchAgent at
`~/Library/LaunchAgents/com.ghot.display-control.plist`, and links the command
and icon into `~/.config/raycast/scripts`. The agent starts at graphical login
and restarts after unexpected failure. No root access is required.

Add `~/.config/raycast/scripts` to Raycast Script Commands and use
**Toggle Internal Display** (optionally assign a hotkey).

`./manage.sh link` only installs the command and icon links; it leaves the
running service untouched. Both `link` and `install` refuse to replace files
or links belonging to another location. If moving the checkout, remove the
two old project links before running `link` from the new location. Uninstall
removes only command links pointing to this project directory.

## Behavior and Recovery

First installation starts paused. Toggle enables automatic disconnect when an
external display is active; toggling again persists pause before restoring the
built-in display. The mode survives sleep, process restart, and reboot. Mirrored
desktops are not automatically changed: use an extended desktop. Disable other
apps' automatic display control before enabling this service. Native direct
connections and docks share the same active-display check; DisplayLink, Sidecar,
and virtual display workflows are not validated.
The system's `unkn`/`virt` fallback screen is excluded from external-display
counts and mode restoration so it cannot block recovery after physical unplug.

Switching the built-in display can make macOS load a different saved external
display mode. The controller captures external modes before each layout change
and restores only modes that changed, verifying the result. Correcting an old
saved mode can briefly interrupt the external signal on the first switch;
continuous physical output is not guaranteed by an active-display status check.

The daemon listens for display, hardware, system sleep, AppKit display sleep,
and powerd user-activity events. It re-reads CoreGraphics display sleep state
before each decision; an external display becoming inactive during display
sleep is not treated as an unplug requiring immediate recovery. The powerd
notification is only a trigger to query current state, not a display detector.
Automatic disconnect requires a stable external identity and mode for at least
three seconds; unplug recovery bypasses that settling interval. A two-second
safety check runs while the panel is managed, recovery is outstanding, or an
external connection is settling. It continues through display-only sleep so a
missed wake event cannot strand recovery, but stops during system sleep and when
idle with only the internal panel. Pause during display sleep restores the panel
after waking. Operation errors preserve the user's automatic/pause choice.
Failed disconnects trigger recovery first; failed recovery retains responsibility
and retries with backoff capped at 60 seconds. Successful recovery permits
automatic disconnect again after cooldown and settling. Process restart restores
an outstanding managed panel before resuming automation. Pause is accepted even
while a worker is busy and restoration follows that worker. Restoring the internal
panel takes priority over preserving external modes. API status cannot guarantee
that a physical panel is lit, and recovery after unplug is not instantaneous.
Mode state is stored outside Git under
`~/Library/Application Support/display-control`, and timestamped lifecycle and operation logs go to
`~/Library/Logs/display-control.log`. Use `~/.local/libexec/display-control status`
to inspect mode and `probe` for read-only API/display checks. The internal
`worker` command is for daemon subprocesses, not user scripts.
Logs include display sleep detection sources, API step timestamps, and worker
durations. Worker output is collected on exit, including after a timeout, so
step timestamps may appear after more recent daemon events in the file. A step
without completion before timeout identifies the last operation attempted;
API state still does not prove that a physical panel is lit.

`./manage.sh uninstall` pauses and confirms that the internal display is active
and no recovery is pending before removing the service and binary. If sleeping,
closed, busy, or still recovering, it retains the installation; wake/open the
display and retry. It also checks recovery state when the service is unloaded.
Mode state and logs are retained. Updating via `install`
also pauses an existing service. If the daemon is unavailable, use
`./manage.sh start`. If the panel cannot be restored, try opening
the lid, reconnecting the external display, or rebooting. Test physical hotplug,
sleep/wake, unplug during sleep, lid cycles, and both direct/dock paths on the
actual hardware before relying on automation.

`./manage.sh check` compiles the source and runs non-disruptive tests.
After installing the current source, pause automation and run
`./manage.sh check-live` to disconnect and restore the actual built-in display
and check that external modes are preserved. This uses the installed daemon's
normal toggle/pause commands, so recovery responsibility survives interruption
or display sleep. Normal completion leaves automation paused; if the test is
forcibly stopped, automation may remain enabled and can be paused in Raycast.
It requires an open lid and an external display in extended mode. This opt-in
hardware check is excluded from `./check`; observe the external picture without
moving the mouse to also check for a black screen that requires user activity.
