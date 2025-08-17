#!/usr/bin/env python3
"""
termclip — cross-platform terminal clipboard helper.

Usage:
  echo "hello" | termclip
  cat file.txt | termclip
  termclip --paste               # best-effort paste (local only)
  TERMCLIP_FORCE_OSC52=1 cat x | termclip
  TERMCLIP_FORCE_NATIVE=1 cat x | termclip
  TERMCLIP_DEBUG=1 cat x | termclip  # debug output
  termclip --help
"""

import argparse
import base64
import os
import shutil
import subprocess
import sys
from typing import Optional

# ---------------------------- helpers ----------------------------------------

def _debug(msg: str) -> None:
    if os.environ.get("TERMCLIP_DEBUG") == "1":
        print(f"[DEBUG] {msg}", file=sys.stderr)

def _have(cmd: str) -> bool:
    return shutil.which(cmd) is not None

def _read_stdin_bytes() -> bytes:
    return sys.stdin.buffer.read()

def _write_bytes_to(cmd: str, args: list, data: bytes, timeout: Optional[float] = None) -> bool:
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

def _check_tmux_config() -> tuple[bool, bool]:
    """Check tmux clipboard and passthrough settings."""
    if "TMUX" not in os.environ:
        return True, True  # Not in tmux, assume OK
    
    try:
        # Check set-clipboard setting
        clipboard_result = subprocess.run(
            ["tmux", "show-options", "-g", "set-clipboard"], 
            capture_output=True, text=True
        )
        clipboard_on = "on" in clipboard_result.stdout if clipboard_result.returncode == 0 else False
        
        # Check allow-passthrough setting (tmux 3.3+)
        passthrough_result = subprocess.run(
            ["tmux", "show-options", "-g", "allow-passthrough"], 
            capture_output=True, text=True
        )
        passthrough_on = "on" in passthrough_result.stdout if passthrough_result.returncode == 0 else False
        
        _debug(f"tmux set-clipboard: {clipboard_on}, allow-passthrough: {passthrough_on}")
        return clipboard_on, passthrough_on
        
    except Exception as e:
        _debug(f"Failed to check tmux config: {e}")
        return False, False

def _copy_tmux(data: bytes) -> bool:
    """Try tmux's built-in clipboard commands first."""
    if "TMUX" not in os.environ:
        return False
    
    _debug("Trying tmux native clipboard")
    
    try:
        text = data.decode("utf-8", errors="replace")
        
        # Check tmux version first
        version_result = subprocess.run(["tmux", "-V"], capture_output=True, text=True)
        _debug(f"tmux version: {version_result.stdout.strip()}")
        
        # Method 1: Try tmux set-buffer + copy-buffer (tmux 2.6+)
        p1 = subprocess.run(["tmux", "set-buffer", text], capture_output=True, text=True)
        if p1.returncode != 0:
            _debug(f"tmux set-buffer failed: {p1.stderr}")
            return False
            
        # Try to copy buffer to system clipboard
        p2 = subprocess.run(["tmux", "copy-buffer"], capture_output=True, text=True)
        if p2.returncode == 0:
            _debug("tmux copy-buffer succeeded")
            return True
        else:
            _debug(f"tmux copy-buffer failed: {p2.stderr}")
            
        # Method 2: Fallback for older tmux - try save-buffer to system clipboard
        if "unknown command" in p2.stderr:
            _debug("copy-buffer not available, trying alternative method")
            # For older tmux, we can't directly copy to system clipboard
            # Let OSC 52 handle it instead
            return False
            
    except Exception as e:
        _debug(f"tmux native failed with exception: {e}")
        
    return False

def _copy_native(data: bytes) -> bool:
    # Respect explicit override to *skip* native and use OSC-52.
    if os.environ.get("TERMCLIP_FORCE_OSC52") == "1":
        _debug("Forcing OSC52, skipping native")
        return False

    # Try tmux clipboard first if we're in tmux
    if _copy_tmux(data):
        return True

    plat = sys.platform
    _debug(f"Trying native clipboard for platform: {plat}")

    # macOS
    if plat == "darwin" and _have("pbcopy"):
        _debug("Trying pbcopy")
        return _write_bytes_to("pbcopy", [], data)

    # Windows
    if plat.startswith("win"):
        if _have("clip"):
            _debug("Trying clip")
            return _write_bytes_to("clip", [], data)
        # PowerShell fallback
        if _have("powershell"):
            _debug("Trying powershell")
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
    
    _debug(f"Wayland: {have_wayland}, X11: {have_x11}")

    # Wayland (no -f -> returns immediately)
    if have_wayland and _have("wl-copy"):
        _debug("Trying wl-copy")
        return _write_bytes_to("wl-copy", [], data)

    # X11
    if have_x11 and _have("xclip"):
        _debug("Trying xclip")
        # tiny timeout so pipeline doesn't linger
        return _write_bytes_to("xclip", ["-selection", "clipboard", "-in", "-quiet"], data, timeout=0.2)
    if have_x11 and _have("xsel"):
        _debug("Trying xsel")
        return _write_bytes_to("xsel", ["--clipboard", "--input"], data, timeout=0.2)

    _debug("No native clipboard method available")
    return False

# --------------------------- OSC 52 copy -------------------------------------

def _osc52_wrap(payload_b64: str) -> bytes:
    """
    Build an OSC 52 sequence. If inside tmux/screen, wrap accordingly.
    """
    # Use ST (String Terminator) instead of BEL for better compatibility
    osc = f"\033]52;c;{payload_b64}\033\\"
    
    _debug(f"Original OSC sequence length: {len(osc)}")

    # tmux pass-through - Multiple approaches
    if "TMUX" in os.environ:
        _debug("In tmux, wrapping OSC sequence")
        
        # Method 1: Standard tmux passthrough with doubled ESCs
        escaped_osc = osc.replace("\033", "\033\033")
        wrapped = f"\033Ptmux;{escaped_osc}\033\\"
        _debug(f"Tmux wrapped sequence length: {len(wrapped)}")
        return wrapped.encode("utf-8", errors="replace")
        
    # screen pass-through
    elif os.environ.get("STY") and os.environ.get("TERM", "").startswith("screen"):
        _debug("In screen, wrapping OSC sequence")
        osc = f"\033P{osc}\033\\"

    return osc.encode("utf-8", errors="replace")

def _copy_osc52(data: bytes) -> bool:
    """
    Send OSC 52 to controlling TTY (preferred), else to stdout if it's a TTY.
    Many terminals cap OSC 52 payloads (~100KB base64). We truncate and warn.
    """
    # Allow forcing OSC-52 even if native is present
    if os.environ.get("TERMCLIP_FORCE_NATIVE") == "1":
        _debug("Forcing native, skipping OSC52")
        return False

    _debug("Trying OSC52 clipboard")
    
    MAX_B64 = int(os.environ.get("TERMCLIP_OSC52_MAX_B64", "75000"))
    b64 = base64.b64encode(data).decode("ascii")
    truncated = False
    
    _debug(f"Base64 length: {len(b64)}, max: {MAX_B64}")
    
    if len(b64) > MAX_B64:
        b64 = b64[:MAX_B64]
        truncated = True
        _debug("Content truncated for OSC52")

    seq = _osc52_wrap(b64)
    _debug(f"Final sequence length: {len(seq)}")

    # Method 1: Try /dev/tty first
    success = False
    try:
        _debug("Trying to write to /dev/tty")
        with open("/dev/tty", "wb", buffering=0) as tty:
            tty.write(seq)
            tty.flush()
            success = True
            _debug("Successfully wrote to /dev/tty")
    except Exception as e:
        _debug(f"Failed to write to /dev/tty: {e}")
        
        # Method 2: Fallback to stdout if it's a TTY
        if sys.stdout.isatty():
            try:
                _debug("Trying to write to stdout")
                sys.stdout.buffer.write(seq)
                sys.stdout.buffer.flush()
                success = True
                _debug("Successfully wrote to stdout")
            except Exception as e2:
                _debug(f"Failed to write to stdout: {e2}")

    # Method 3: If in tmux, also try tmux's display-message as a fallback
    if not success and "TMUX" in os.environ:
        try:
            _debug("Trying tmux display-message method")
            # Send the raw OSC sequence via tmux
            raw_osc = f"\033]52;c;{b64}\033\\"
            subprocess.run(["tmux", "send-keys", "-t", "0", f"printf '{raw_osc}'"], 
                         capture_output=True, check=False)
            success = True
            _debug("tmux display-message method attempted")
        except Exception as e:
            _debug(f"tmux display-message failed: {e}")

    if success and truncated:
        sys.stderr.write("[termclip] Note: content truncated to fit OSC 52 limits.\n")
        sys.stderr.flush()
    
    return success

# ----------------------------- paste -----------------------------------------

def _paste_tmux() -> int:
    """Try to paste from tmux buffer first."""
    if "TMUX" not in os.environ:
        return None
    
    _debug("Trying tmux paste")
    
    try:
        # Try to show tmux buffer
        p = subprocess.run(["tmux", "show-buffer"], stdout=sys.stdout, stderr=subprocess.PIPE)
        if p.returncode == 0:
            _debug("tmux show-buffer succeeded")
        else:
            _debug(f"tmux show-buffer failed: {p.stderr.decode()}")
        return p.returncode
    except Exception as e:
        _debug(f"tmux paste failed: {e}")
        return None

def paste_text() -> int:
    """
    Best-effort paste (LOCAL machine only).
    Over SSH, reading the local clipboard from the remote host is not possible
    without a helper. Run --paste on your local machine.
    """
    # Try tmux first if available
    tmux_result = _paste_tmux()
    if tmux_result is not None:
        return tmux_result

    plat = sys.platform
    _debug(f"Trying paste for platform: {plat}")

    # macOS
    if plat == "darwin" and _have("pbpaste"):
        _debug("Trying pbpaste")
        p = subprocess.run(["pbpaste"], stdout=sys.stdout)
        return p.returncode

    # Windows
    if plat.startswith("win"):
        for ps_name in ("powershell", "powershell.exe"):
            if _have(ps_name):
                _debug(f"Trying {ps_name}")
                p = subprocess.run([ps_name, "-NoProfile", "-Command", "Get-Clipboard -Raw"], stdout=sys.stdout)
                return p.returncode

    # Wayland/X11
    if os.environ.get("WAYLAND_DISPLAY") and _have("wl-paste"):
        _debug("Trying wl-paste")
        p = subprocess.run(["wl-paste", "-n"], stdout=sys.stdout)
        return p.returncode
    if os.environ.get("DISPLAY"):
        if _have("xclip"):
            _debug("Trying xclip paste")
            p = subprocess.run(["xclip", "-selection", "clipboard", "-o"], stdout=sys.stdout)
            return p.returncode
        if _have("xsel"):
            _debug("Trying xsel paste")
            p = subprocess.run(["xsel", "--clipboard", "--output"], stdout=sys.stdout)
            return p.returncode

    sys.stderr.write("termclip: paste not supported here (no native clipboard command found). On SSH, run --paste locally.\n")
    return 1

# ------------------------------ main -----------------------------------------

def copy_bytes(data: bytes) -> int:
    if not data:
        _debug("No data to copy")
        return 0

    _debug(f"Copying {len(data)} bytes")
    _debug(f"TMUX: {os.environ.get('TMUX', 'not set')}")
    _debug(f"DISPLAY: {os.environ.get('DISPLAY', 'not set')}")
    _debug(f"WAYLAND_DISPLAY: {os.environ.get('WAYLAND_DISPLAY', 'not set')}")

    # Check tmux configuration if in tmux
    if "TMUX" in os.environ:
        clipboard_on, passthrough_on = _check_tmux_config()
        
        if not clipboard_on:
            sys.stderr.write("⚠️  tmux clipboard integration is OFF. Add 'set -g set-clipboard on' to ~/.tmux.conf\n")
            
        if not passthrough_on:
            sys.stderr.write("⚠️  tmux passthrough is OFF. Add 'set -g allow-passthrough on' to ~/.tmux.conf for better OSC 52 support\n")
            
        if not clipboard_on or not passthrough_on:
            sys.stderr.write("   Then run: tmux source-file ~/.tmux.conf\n")

    # Prefer native unless explicitly forcing OSC-52
    if _copy_native(data):
        _debug("Native clipboard succeeded")
        return 0

    if _copy_osc52(data):
        _debug("OSC52 clipboard succeeded")
        
        # Additional warnings for tmux users
        if "TMUX" in os.environ:
            clipboard_on, passthrough_on = _check_tmux_config()
            if not clipboard_on or not passthrough_on:
                sys.stderr.write("📋 Clipboard data sent via OSC 52. If pasting doesn't work, check tmux config above.\n")
            else:
                sys.stderr.write("📋 Clipboard data sent via OSC 52.\n")
        
        return 0

    _debug("All clipboard methods failed")
    
    # Enhanced error message for tmux users
    if "TMUX" in os.environ:
        clipboard_on, passthrough_on = _check_tmux_config()
        if not clipboard_on or not passthrough_on:
            sys.stderr.write(
                "termclip: clipboard failed. Your tmux config may need:\n"
                "  set -g set-clipboard on\n"
                "  set -g allow-passthrough on\n"
                "Then: tmux source-file ~/.tmux.conf\n"
            )
        else:
            sys.stderr.write(
                "termclip: clipboard failed. Your terminal may not support OSC 52.\n"
                "Try a terminal that supports OSC 52 (kitty, alacritty, newer gnome-terminal).\n"
            )
    else:
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