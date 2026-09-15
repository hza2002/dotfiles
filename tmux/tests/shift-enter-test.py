#!/usr/bin/env python3
"""Exercise Ghostty's configured bytes through tmux's real root key table."""

import codecs
import fcntl
import os
from pathlib import Path
import pty
import shlex
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tty


def capture(path):
    tty.setraw(0)
    os.write(1, b"\x1b[>4;2m")  # CLI requests modifyOtherKeys mode 2.
    with open(path, "ab", buffering=0) as output:
        while True:
            output.write(os.read(0, 256))


def main():
    root = Path(__file__).resolve().parents[2]
    prefix = "keybind = shift+enter="
    action = next(
        line[len(prefix):]
        for line in (root / "ghostty/.config/ghostty/config").read_text().splitlines()
        if line.startswith(prefix)
    )
    if action.startswith("csi:"):
        configured = b"\x1b[" + action[4:].encode("ascii")
    elif action.startswith("text:"):
        configured = codecs.decode(action[5:], "unicode_escape").encode("ascii")
    else:
        raise AssertionError(f"Unsupported Shift+Enter action: {action}")

    with tempfile.TemporaryDirectory(prefix="dotfiles-key-test-") as directory:
        socket = str(Path(directory) / "socket")
        output = Path(directory) / "input"
        output.touch()
        tmux = [os.environ.get("TMUX_BIN", "tmux"), "-S", socket]

        def tm(*args):
            return subprocess.check_output([*tmux, *args], text=True).strip()

        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        client = None
        try:
            tm("-f", "/dev/null", "new-session", "-d", "-s", "probe", "sleep 30")
            for name in ("options", "bindings"):
                tm("source-file", str(root / f"tmux/.config/tmux/conf/{name}.conf"))
            client = subprocess.Popen(
                [*tmux, "attach-session", "-t", "probe"],
                stdin=slave, stdout=slave, stderr=slave,
                env={**os.environ, "TERM": "xterm-ghostty"},
            )
            command = shlex.join([sys.executable, __file__, "--capture", str(output)])
            tm("respawn-pane", "-k", "-t", "probe", command)
            for _ in range(100):
                if tm("display-message", "-p", "-t", "probe", "#{pane_key_mode}") == "Ext 2":
                    break
                time.sleep(0.02)
            else:
                raise AssertionError("Capture process did not enable extended keys")

            def expect(label, sequence, expected):
                offset = output.stat().st_size
                # A following printable key proves processing completed even when
                # the preceding key was swallowed by the pane-navigation binding.
                os.write(master, sequence + b"X")
                for _ in range(100):
                    received = output.read_bytes()[offset:]
                    if received.endswith(b"X"):
                        break
                    time.sleep(0.02)
                if received != expected + b"X":
                    raise AssertionError(f"{label}: expected {expected!r}, got {received!r}")
                print(f"ok - {label}")

            expect("Ctrl-J is consumed by pane navigation", b"\n", b"")
            expected_shift = (
                b"\x1b[13;2u"
                if tm("display-message", "-p", "#{>=:#{version},3.5}") == "1"
                else b"\x1b[27;2;13~"
            )
            expect("configured Shift+Enter reaches the CLI", configured, expected_shift)
            expect("plain Enter stays distinct", b"\r", b"\r")
        finally:
            subprocess.run([*tmux, "kill-server"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if client is not None:
                client.wait(timeout=5)
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--capture":
        capture(sys.argv[2])
    else:
        main()
