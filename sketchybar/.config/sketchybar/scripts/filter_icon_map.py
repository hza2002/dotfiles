#!/usr/bin/env python3
"""Filter icon_map.sh to only include icons for installed applications.

┌─────────────────────────────────────────────────────────────────────────────┐
│ README FOR AGENTS / MAINTAINERS — read this before touching anything        │
└─────────────────────────────────────────────────────────────────────────────┘

PURPOSE
  The sketchybar-app-font release maps hundreds of apps → icons. We don't need
  all of them. This script filters icon_map.sh down to only the apps
  actually installed on this Mac, plus a curated set of CLI tools and common
  apps the user might run from outside /Applications.

PIPELINE (invoked by ~/.config/sketchybar/scripts/install-app-font)
  1. Download latest release       →  private temporary files
  2. This script                   →  filters the temporary icon_map.sh
  3. Validate and install          →  atomically replaces the live files

INPUT
  The FULL upstream icon_map.sh passed with --input. The script filters the
  section between ### START-OF-ICON-MAP and ### END-OF-ICON-MAP.

OUTPUT
  The path passed with --output. A fixed --batch footer is appended so the
  output always has the batch-mode handler (overwrites any upstream footer).

CONFIG: ~/.config/sketchybar/icon_map_keep
  One app name per line, # for comments. Apps listed here are treated as
  "installed" even if no .app bundle exists. Use this to permanently keep
  icon mappings for apps you plan to install or use occasionally.
  Example:
    # Apps I might install later
    Arc
    Figma
    # CLI tools with distinct window titles
    python

MATCHING RULES (an entry is KEPT if ANY of its patterns satisfy one rule)
  1. EXACT MATCH — a pattern equals an installed .app name (e.g. "Safari")
  2. PREFIX MATCH — an installed .app name starts with the pattern and the
     remainder looks like a version/edition/platform suffix.
     Examples: pattern "Alfred" matches installed "Alfred 5"
               pattern "MATLAB" matches installed "MATLAB_R2025b"
               pattern "BaiduNetdisk" matches installed "BaiduNetdisk_mac"
     This is intentionally conservative — it will NOT match:
       "Code" → "Codex"         (no version separator)
       "Claude" → "Claude Code URL Handler"  (unrecognized suffix)
  3. CLI/DEV TOOL — the pattern is in the hardcoded CLI_PATTERNS set below.
     These are typically lowercase command names (kitty, neovim, mpv, yazi)
     or special cases (Electron for dev builds, Code for VS Code variants).

TROUBLESHOOTING: "Why does app X show :default: icon?"

  Step 1 — Is X in the upstream icon_map at all?
    curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/icon_map.sh | grep -i '"X"'
    If found → skip to Step 2.
    If NOT found → X has no icon mapping upstream. But an SVG might still exist:
      Search the upstream repository's svgs directory for '<keyword>'.
    If an SVG exists but no mapping file (common for utility icons like :vpn:,
    :vpnoff:, :widget:, :wifi:, etc.), you can reuse it — skip to Step 3 Option C.
    If no SVG exists either, you need to contribute one to sketchybar-app-font,
    or accept the :default: icon.

  Step 2 — Was the entry filtered out?
    Run: ~/.config/sketchybar/scripts/install-app-font
    It downloads the complete upstream map before filtering and prints
    "Kept N entries, removed M". Then:
    grep -i '"X"' ~/.config/sketchybar/plugins/icon_map.sh
    If NOT found → the entry exists upstream but was filtered out. Reason is
    usually: X is not in /Applications AND not in CLI_PATTERNS AND not in
    icon_map_keep.

  Step 3 — Fix it:
    Option A: Add X to ~/.config/sketchybar/icon_map_keep (create the file if
              it doesn't exist; one app name per line, # for comments).
    Option B: If X is a CLI/dev tool, add it to CLI_PATTERNS in this file.
    Option C: If an SVG exists upstream but has no mapping file, create one:
              Submit the missing mapping upstream, then rerun:
              ~/.config/sketchybar/scripts/install-app-font
    After any option, re-run install-app-font. A filtered map is not a complete
    source and must not be filtered again.

  Step 4 — Is the app name different from the .app bundle name?
    yabai reports the CFBundleName / localized name, which may differ from
    the .app directory name. Check what yabai sees:
      yabai -m query --windows | jq -r '.[].app' | sort -u
    If the name yabai reports differs from the .app name AND from all
    patterns in icon_map, add the yabai-reported name to icon_map_keep.

  Step 5 — Still not working?
    The "Code" / "Electron" / "Code - Insiders" pattern is kept via
    CLI_PATTERNS. If your app window shows as "electron" (lowercase), it
    won't match "Electron" (capital E). Check if the case matches.

APP DISCOVERY
  This script scans these directories for .app bundles:
    /Applications
    /System/Applications
    /System/Applications/Utilities
    ~/Applications
  Plus "Finder" (always present, no .app bundle).
  Plus whatever is listed in icon_map_keep.

  Apps NOT in these directories that might still appear in yabai windows:
  - Homebrew casks in /opt/homebrew/Caskroom → NOT scanned (add to keep file)
  - CLI tools (nvim, kitty, etc.) → should be in CLI_PATTERNS
  - Apps launched from .dmg without installing → NOT scanned
  - X11/XQuartz apps → NOT scanned (add to keep file if needed)
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Optional

KEEP_FILE = Path.home() / ".config/sketchybar/icon_map_keep"

START_MARKER = "### START-OF-ICON-MAP"
END_MARKER = "### END-OF-ICON-MAP"

APP_DIRS = [
    "/Applications",
    "/System/Applications",
    "/System/Applications/Utilities",
    f"{Path.home()}/Applications",
]

# Patterns that are NEVER conventional macOS .app names — CLI tools, daemons, etc.
# These entries are always kept even if no .app bundle exists.
CLI_PATTERNS: set[str] = {
    "alacritty", "Alacritty",
    "cmus", "cmux",
    "calibre",
    "deno",
    "Code",
    "Electron",
    "foobar2000",
    "kitty",
    "krita",
    "legcord", "Legcord",
    "mpv",
    "neovide", "neovim", "nvim", "Neovim", "Neovide",
    "opencode",
    "qutebrowser",
    "rekordbox",
    "ruffle",
    "sioyek",
    "solidtime",
    "wezterm-gui",
    "xemu",
    "yazi", "Yazi",
    "aw-tauri",
}

# Suffix pattern: must look like a version number, edition, or platform tag.
_VERSION_SUFFIX_RE = re.compile(
    r"^[\s_]"            # separator: space or underscore
    r"(?:"
    r"\d[\d.]*"          # version number: 5, 2025, 2.0
    r"|R\d+[a-z]*"      # release: R2025b
    r"|Pro|Studio|RC|Beta|Canary|Dev|Preview|Nightly|Lite"
    r"|Enterprise|Professional|Ultimate|Business|Community"
    r"|for\s+(Mac|macOS|Desktop)"
    r"|Desktop|Viewer|Editor|IDE|Player|Browser|VPN"
    r"|Media\s+Player|Chat|App|Companion|Mini|Helper"
    r"|Assistant|Client|Manager|Monitor|Settings"
    r"|Configuration|Console|Dashboard|Gateway|Toolbox"
    r"|Link|Handler|Launcher|Tracker|Cleaner|Converter"
    r"|mac"               # platform suffix: _mac, -mac
    r")$"
)

# Minimum prefix length to avoid false matches like "Min" → "MinerU"
MIN_PREFIX_LEN = 4


def list_installed_apps() -> set[str]:
    """Return discovered names from installed .app bundles and explicit extras."""
    names: set[str] = set()
    for d in APP_DIRS:
        p = Path(d)
        if not p.is_dir():
            continue
        for entry in p.iterdir():
            if entry.suffix == ".app":
                names.add(entry.stem)
    names.add("Finder")
    # Load extras from keep file
    if KEEP_FILE.is_file():
        for line in KEEP_FILE.read_text().splitlines():
            name = line.strip()
            if name and not name.startswith("#"):
                names.add(name)
    return names


def parse_pattern_specs(pattern_lines: list[str]) -> list[tuple[str, bool]]:
    """Parse quoted case patterns with an optional trailing wildcard."""
    expression = " ".join(line.strip() for line in pattern_lines).rsplit(")", 1)[0]
    if not re.fullmatch(r'"[^"]*"\*?(?:\s*\|\s*"[^"]*"\*?)*', expression):
        return []
    return [
        (match.group(1), bool(match.group(2)))
        for match in re.finditer(r'"([^"]*)"(\*)?', expression)
    ]


def is_version_suffix(installed: str, pattern: str) -> bool:
    """Check if 'installed' is 'pattern' + a version/edition suffix."""
    remaining = installed[len(pattern):]
    if not remaining:
        return True  # exact match handled elsewhere
    return bool(_VERSION_SUFFIX_RE.match(remaining))


def is_cli_entry(patterns: list[str]) -> bool:
    """Return True if this entry is for CLI/non-bundle tools (always keep)."""
    return any(p in CLI_PATTERNS for p in patterns)


def matches_installed(pattern_name: str, installed: set[str]) -> bool:
    """Check if a pattern matches an installed app (exact or prefix)."""
    if pattern_name in installed:
        return True
    # Prefix match: pattern must be long enough to avoid false matches
    if len(pattern_name) >= MIN_PREFIX_LEN:
        for app in installed:
            if app.startswith(pattern_name) and is_version_suffix(app, pattern_name):
                return True
    # Also check the reverse: installed app is a prefix of the pattern
    # (handles cases like "Acrobat" matching installed "Adobe Acrobat" — not needed for us)
    return False


def _is_pattern_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False
    if stripped.startswith(("function", "case", "icon_result", "*")):
        return False
    if stripped == ";;":
        return False
    return stripped.startswith('"')


def _shell_case_pattern(value: str) -> str:
    """Quote a literal case pattern without allowing shell expansion."""
    return "'" + value.replace("'", "'\\''") + "'"


def _parse_icon_assignment(lines: list[str]) -> Optional[str]:
    body = " ".join(line.strip() for line in lines if line.strip())
    match = re.fullmatch(r'icon_result="(:[a-z0-9_-]+:)"\s*;;', body)
    if match is None:
        return None
    return match.group(1)


def filter_icon_map(input_path: Path, output_path: Path) -> int:
    if not input_path.is_file():
        print(f"ERROR: {input_path} not found", file=sys.stderr)
        return 1

    installed = list_installed_apps()
    print(f"Found {len(installed)} installed apps (including extras)")

    content = input_path.read_text()
    start = content.find(START_MARKER)
    end = content.find(END_MARKER)
    if start == -1 or end == -1:
        print(f"ERROR: markers not found in {input_path}", file=sys.stderr)
        return 1

    header = """#!/usr/bin/env bash

### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
"""

    # Footer: always use our --batch code, never the dist standalone code
    footer = """
if [ "$1" = "--batch" ]; then
  shift
  for app in "$@"; do
    __icon_map "$app"
    echo "$icon_result"
  done
else
  __icon_map "$1"
  echo "$icon_result"
fi
"""

    map_section = content[start + len(START_MARKER) : end]
    lines = map_section.split("\n")
    output_lines: list[str] = []
    i = 0
    kept = 0
    skipped = 0
    cli_kept = 0
    prefix_matched: list[str] = []
    required_icons: dict[str, str] = {}
    default_icon: Optional[str] = None
    default_seen = False

    while i < len(lines):
        line = lines[i]

        if line.strip().startswith("*)"):
            if default_seen:
                print("ERROR: duplicate default icon entry", file=sys.stderr)
                return 1
            default_seen = True
            default_lines = []
            inline_body = line.rsplit(")", 1)[1].strip()
            if inline_body:
                default_lines.append(inline_body)
            i += 1
            while not any(";;" in part for part in default_lines) and i < len(lines):
                default_lines.append(lines[i])
                i += 1
            default_icon = _parse_icon_assignment(default_lines)
            if default_icon is None:
                print("ERROR: invalid default icon entry", file=sys.stderr)
                return 1
            continue

        if not _is_pattern_line(line):
            if line.strip() not in {"", 'function __icon_map() {', 'case "$1" in', "esac", "}"}:
                print(f"ERROR: unsupported shell content: {line.strip()}", file=sys.stderr)
                return 1
            i += 1
            continue

        # Collect pattern lines for this entry
        pattern_lines = [line]
        i += 1
        while i < len(lines) and ")" not in lines[i - 1]:
            if _is_pattern_line(lines[i]):
                pattern_lines.append(lines[i])
            i += 1

        # Collect remaining lines until ;;
        entry_body: list[str] = []
        inline_body = pattern_lines[-1].rsplit(")", 1)[1].strip()
        if inline_body:
            entry_body.append(inline_body)
        while not any(";;" in part for part in entry_body) and i < len(lines):
            entry_body.append(lines[i])
            i += 1

        # Decide
        pattern_specs = parse_pattern_specs(pattern_lines)
        if not pattern_specs:
            print("ERROR: icon entry has invalid literal patterns", file=sys.stderr)
            return 1
        all_pats = [pattern for pattern, _ in pattern_specs]
        icon = _parse_icon_assignment(entry_body)
        if icon is None:
            print(f"ERROR: invalid icon entry for {all_pats[0]}", file=sys.stderr)
            return 1
        duplicate = next((pattern for pattern in all_pats if pattern in required_icons), None)
        if duplicate is not None:
            print(f"ERROR: duplicate icon pattern: {duplicate}", file=sys.stderr)
            return 1
        for pattern in set(all_pats):
            required_icons[pattern] = icon

        normalized_entry = [
            f"    {' | '.join(_shell_case_pattern(pattern) + ('*' if wildcard else '') for pattern, wildcard in pattern_specs)})",
            f'      icon_result="{icon}"',
            "      ;;",
        ]

        if is_cli_entry(all_pats):
            output_lines.extend(normalized_entry)
            kept += 1
            cli_kept += 1
            continue

        matched = False
        for name in all_pats:
            if matches_installed(name, installed):
                matched = True
                if name not in installed:  # prefix match
                    prefix_matched.append(
                        f"  {name} → {[a for a in installed if a.startswith(name) and is_version_suffix(a, name)]}"
                    )
                break

        if matched:
            output_lines.extend(normalized_entry)
            kept += 1
        else:
            skipped += 1

    if required_icons.get("Code") != ":code:" or default_icon != ":default:":
        print("ERROR: upstream map does not satisfy the Code/default contract", file=sys.stderr)
        return 1

    output_lines.extend([
        "    *)",
        f'      icon_result="{default_icon}"',
        "      ;;",
        "  esac",
        "}",
    ])
    new_content = header + "\n".join(output_lines) + "\n" + footer
    output_path.write_text(new_content)

    print(f"Kept {kept} entries (incl. {cli_kept} CLI/dev), removed {skipped}")
    if prefix_matched:
        print(f"Prefix-matched entries:")
        for pm in prefix_matched:
            print(pm)

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="complete upstream icon_map.sh")
    parser.add_argument("--output", type=Path, required=True, help="filtered output path")
    args = parser.parse_args()
    sys.exit(filter_icon_map(args.input, args.output))
