#!/usr/bin/env python3
"""
termclip — cross-platform terminal clipboard helper.

Usage:
  echo "hello" | termclip
  cat file.txt | termclip
  termclip --paste               # best-effort paste (local only)
  TERMCLIP_FORCE_OSC52=1 cat x | termclip
  TERMCLIP_FORCE_NATIVE=1 cat x | termclip
  termclip --help
"""

import argparse
import base64
import os
import shutil
import subprocess
import sys

# ---------------------------- helpers ----------------------------------------

def _have(cmd: str) -> bool:
    return shutil.which(cmd) is not None

def _read_stdin_bytes() -> bytes:
    return sys.stdin.buffer.read()

def _write_bytes_to(cmd: str, args: list, data: bytes, timeout: float | None = None) -> bool:
    try:
        p = subprocess.Popen([cmd] + args, stdin=subprocess.PIPE)
        p.stdin.write(data)
        p.stdin.close()
        if timeout is None:
            return p.wait() == 0
        try:
            return p.wait(timeout=timeout) == 0
        except subprocess.TimeoutExpired:
            # Still running (serving the clipboard) — assume success.
            return True
    except Exception:
        return False

# --------------------------- native copy -------------------------------------

def _copy_native(data: bytes) -> bool:
    # Respect explicit override to *skip* native and use OSC-52.
    if os.environ.get("TERMCLIP_FORCE_OSC52") == "1":
        return False

    plat = sys.platform

    # macOS
    if plat == "darwin" and _have("pbcopy"):
        return _write_bytes_to("pbcopy", [], data)

    # Windows
    if plat.startswith("win"):
        if _have("clip"):
            return _write_bytes_to("clip", [], data)
        # PowerShell fallback
        if _have("powershell"):
            try:
                text = data.decode("utf-8", errors="replace")
                ps = [
                    "powershell", "-NoProfile", "-Command",
                    "Set-Clipboard -Value ([Console]::In.ReadToEnd())"
                ]
                p = subprocess.Popen(ps, stdin=subprocess.PIPE, encoding="utf-8")
                p.stdin.write(text)
                p.stdin.close()
                return p.wait() == 0
            except Exception:
                return False

    # Linux/*BSD GUI clipboards — only if we actually have a display.
    have_wayland = bool(os.environ.get("WAYLAND_DISPLAY"))
    have_x11 = bool(os.environ.get("DISPLAY"))

    # Wayland (no -f -> returns immediately)
    if have_wayland and _have("wl-copy"):
        return _write_bytes_to("wl-copy", [], data)

    # X11
    if have_x11 and _have("xclip"):
        # tiny timeout so pipeline doesn't linger
        return _write_bytes_to("xclip", ["-selection", "clipboard", "-in", "-quiet"], data, timeout=0.2)
    if have_x11 and _have("xsel"):
        return _write_bytes_to("xsel", ["--clipboard", "--input"], data, timeout=0.2)

    return False

# --------------------------- OSC 52 copy -------------------------------------

def _osc52_wrap(payload_b64: str) -> bytes:
    """
    Build an OSC 52 sequence. If inside tmux/screen, wrap accordingly.
    """
    osc = f"\033]52;c;{payload_b64}\a"

    # tmux pass-through
    if "TMUX" in os.environ:
        # DCS passthrough for tmux: ESC P tmux; ESC <OSC> ESC \\
        osc = f"\033Ptmux;\033{osc}\033\\"
    # screen pass-through
    elif os.environ.get("STY") and os.environ.get("TERM", "").startswith("screen"):
        osc = f"\033P{osc}\033\\"

    return osc.encode("ascii", errors="ignore")

def _copy_osc52(data: bytes) -> bool:
    """
    Send OSC 52 to controlling TTY (preferred), else to stdout if it's a TTY.
    Many terminals cap OSC 52 payloads (~100KB base64). We truncate and warn.
    """
    # Allow forcing OSC-52 even if native is present
    if os.environ.get("TERMCLIP_FORCE_NATIVE") == "1":
        return False

    MAX_B64 = int(os.environ.get("TERMCLIP_OSC52_MAX_B64", "75000"))
    b64 = base64.b64encode(data).decode("ascii")
    truncated = False
    if len(b64) > MAX_B64:
        b64 = b64[:MAX_B64]
        truncated = True

    seq = _osc52_wrap(b64)

    # Prefer /dev/tty so it works in pipelines
    try:
        with open("/dev/tty", "wb", buffering=0) as tty:
            tty.write(seq)
            if truncated:
                sys.stderr.write("[termclip] Note: content truncated to fit OSC 52 limits.\n")
            return True
    except Exception:
        pass

    # Fallback: write to stdout only if it's a TTY
    if sys.stdout.isatty():
        try:
            sys.stdout.buffer.write(seq)
            sys.stdout.flush()
            if truncated:
                sys.stderr.write("[termclip] Note: content truncated to fit OSC 52 limits.\n")
            return True
        except Exception:
            return False

    return False

# ----------------------------- paste -----------------------------------------

def paste_text() -> int:
    """
    Best-effort paste (LOCAL machine only).
    Over SSH, reading the local clipboard from the remote host is not possible
    without a helper. Run --paste on your local machine.
    """
    plat = sys.platform

    # macOS
    if plat == "darwin" and _have("pbpaste"):
        p = subprocess.run(["pbpaste"], stdout=sys.stdout)
        return p.returncode

    # Windows
    if plat.startswith("win"):
        for ps_name in ("powershell", "powershell.exe"):
            if _have(ps_name):
                p = subprocess.run([ps_name, "-NoProfile", "-Command", "Get-Clipboard -Raw"], stdout=sys.stdout)
                return p.returncode

    # Wayland/X11
    if os.environ.get("WAYLAND_DISPLAY") and _have("wl-paste"):
        p = subprocess.run(["wl-paste", "-n"], stdout=sys.stdout)
        return p.returncode
    if os.environ.get("DISPLAY"):
        if _have("xclip"):
            p = subprocess.run(["xclip", "-selection", "clipboard", "-o"], stdout=sys.stdout)
            return p.returncode
        if _have("xsel"):
            p = subprocess.run(["xsel", "--clipboard", "--output"], stdout=sys.stdout)
            return p.returncode

    sys.stderr.write("termclip: paste not supported here (no native clipboard command found). On SSH, run --paste locally.\n")
    return 1

# ------------------------------ main -----------------------------------------

def copy_bytes(data: bytes) -> int:
    if not data:
        # no stdin — avoid hanging waiting for input
        return 0

    # Prefer native unless explicitly forcing OSC-52
    if _copy_native(data):
        return 0

    if _copy_osc52(data):
        return 0

    sys.stderr.write(
        "termclip: no clipboard method worked (no pbcopy/clip/wl-copy/xclip/xsel, or terminal refused OSC 52).\n"
    )
    return 1

def main():
    ap = argparse.ArgumentParser(description="Pipe-friendly cross-platform clipboard tool.")
    ap.add_argument("--paste", action="store_true", help="Paste from clipboard to stdout (local only).")
    args = ap.parse_args()

    if args.paste:
        raise SystemExit(paste_text())

    data = _read_stdin_bytes()
    raise SystemExit(copy_bytes(data))

if __name__ == "__main__":
    main()
