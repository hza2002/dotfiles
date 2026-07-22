#!/bin/bash
# Supervisor wrapper for the sketchybar mach helper.
#
# WHY THIS EXISTS: the bar and the helper cache each other's mach port and never
# re-resolve it. If the helper dies on its own (SIGKILL on sleep/wake — the
# signature behind FelixKratz/SketchyBar #497/#97/#422) and is merely relaunched,
# the bar keeps sending to the dead port and items freeze. `sketchybar --reload`
# and re-setting `mach_helper` do NOT recover it — verified. The only reliable
# recovery is to restart the whole service so bar+helper come back together.
#
# The inverse case — bar dying while the helper lives — needs no handling here:
# the helper runs in the bar's process group, so launchd reaps them together.
#
# NOTE: this wrapper calls `launchctl kickstart -k` to restart the bar, and the
# wrapper itself lives in the bar's process group — so `kickstart -k` will kill
# it. This works because launchd queues the restart request before tearing down
# the old process group. Logging after the kickstart call is best-effort; the
# wrapper may be dead before the next write. The new bar's "launching helper"
# log line serves as the confirmation that the restart happened.
set -u

HELPER="${0%/*}/helper"            # real binary beside this script
LOG="${SKETCHYBAR_HELPER_LOG:-/tmp/sketchybar-helper.log}"
BOOTSTRAP="${1:?usage: helper-run.sh <bootstrap-name>}"
SERVICE="${SKETCHYBAR_SERVICE_LABEL:-homebrew.mxcl.sketchybar}"
code=

ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(ts)] [wrapper] launching helper (wrapper pid=$$)" >> "$LOG"

# Run in the foreground so we can block on its real exit status.
start=$(date +%s)
"$HELPER" "$BOOTSTRAP"
code=$?
uptime=$(( $(date +%s) - start ))

if [ -z "${code:-}" ]; then
  code=255
fi

# ── classify exit ────────────────────────────────────────────────────────
# Signal deaths: shell encodes death-by-signal as 128 + signo.
why=""
case "$code" in
  137) why="SIGKILL (9) — external force: wake kill, OOM/jetsam, or bar process-group teardown" ;;
  143) why="SIGTERM (15) — deliberate pkill/reload" ;;
  130) why="SIGINT (2)" ;;
  129) why="SIGHUP (1)" ;;
  75)  why="temporary Mach receive failure" ;;
  0)   why="clean exit (event-server returned)" ;;
esac
if [ -z "$why" ]; then
  if [ "$code" -ge 128 ]; then
    why="killed by signal $((code - 128))"
  else
    why="exited with code $code"
  fi
fi

echo "[$(ts)] [wrapper] helper EXITED code=$code uptime=${uptime}s — $why" >> "$LOG"

# ── decide whether to restart the service ─────────────────────────────────
# Deliberate teardown — sketchybarrc tearing down for a reload, or a normal
# event-server return: the bar is being managed externally, don't interfere.
case "$code" in
  0|143) exit 0 ;;
esac

# Unexpected signal deaths leave the bar with a stale cached helper port. Restart
# the whole service so bar+helper come back as a matched pair. 137/SIGKILL is the
# known wake failure; crashes such as SIGABRT/SIGSEGV end in the same frozen-bar
# state, so they get the same recovery path.
#
# Log BEFORE kickstart: we share the bar's process group and kickstart -k
# kills us, so anything after the call may not reach the log. On success the
# new bar's "launching helper" line confirms the restart; we only log if
# kickstart itself fails.
#
# Clean exits with error (1–127) mean the helper shut itself down. That is not
# known to be fixed by restarting the bar, so log and stop. EX_TEMPFAIL (75) is
# the exception: the receive channel is unusable, so bar+helper must be paired
# again. A short delay bounds repeated recovery attempts if the failure persists.
case "$code" in
  75)
    echo "[$(ts)] [wrapper] Mach receive failed repeatedly — restarting sketchybar service in 1s" >> "$LOG"
    sleep 1
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" >> "$LOG" 2>&1
    ks_rc=$?
    if [ "$ks_rc" -ne 0 ]; then
      echo "[$(ts)] [wrapper] kickstart FAILED (exit=$ks_rc) — bar may be frozen, manual restart needed" >> "$LOG"
    fi
    ;;
  12[8-9]|1[3-9][0-9]|[2-9][0-9][0-9])
    echo "[$(ts)] [wrapper] recent power events:" >> "$LOG"
    pmset -g log 2>/dev/null | grep -iE 'Wake from|Entering Sleep|DarkWake' \
      | tail -4 | sed 's/^/    /' >> "$LOG"
    echo "[$(ts)] [wrapper] helper died from signal — restarting sketchybar service" >> "$LOG"
    launchctl kickstart -k "gui/$(id -u)/$SERVICE" >> "$LOG" 2>&1
    ks_rc=$?
    if [ "$ks_rc" -ne 0 ]; then
      echo "[$(ts)] [wrapper] kickstart FAILED (exit=$ks_rc) — bar may be frozen, manual restart needed" >> "$LOG"
    fi
    ;;
  *)
    echo "[$(ts)] [wrapper] helper died code=$code — NOT restarting service" >> "$LOG"
    ;;
esac
