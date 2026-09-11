#!/usr/bin/env python3
"""Drive the arch-basic VM's real input devices through the QEMU HMP monitor.

This intentionally avoids synthetic input devices (ydotool/uinput): the events
go to the same QEMU HID Tablet the user's physical mouse drives, so what we
verify is the real input path.

Usage:
    hmp.py cmd 'mouse_set 4' 'mouse_move 100 50'
    hmp.py drag-super <button> <dx> <dy>       # Super held across a drag
    hmp.py wheel <dz>
"""

import socket
import sys
import time

SOCK = "/home/xifan/Code/arch-post-install/vms/arch-basic/arch-basic-monitor.socket"

# QEMU HMP key names for held modifiers.
KEY_SUPER = "meta_l"


class Hmp:
    def __init__(self, sock=SOCK):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(sock)
        time.sleep(0.3)
        self._drain()

    def _drain(self, wait=0.25):
        self.s.settimeout(wait)
        out = b""
        try:
            while True:
                chunk = self.s.recv(65536)
                if not chunk:
                    break
                out += chunk
        except TimeoutError:
            pass
        finally:
            self.s.settimeout(None)
        return out.decode(errors="replace")

    def cmd(self, line, wait=0.25):
        self.s.sendall((line + "\n").encode())
        time.sleep(0.05)
        return self._drain(wait)

    def close(self):
        self.s.close()


def selftest():
    h = Hmp()
    out = h.cmd("info mice", 0.8)
    h.close()
    print(out)


def run(cmds):
    h = Hmp()
    for c in cmds:
        h.cmd(c)
    h.close()


def drag_super(button, dx, dy, steps=3, key_hold_ms=4000):
    """Hold Super, press `button`, drag by (dx,dy), release, release Super."""
    h = Hmp()
    # `sendkey` with a long hold returns immediately; the key stays down until
    # the hold expires, which covers the whole mouse sequence below.
    h.cmd(f"sendkey {KEY_SUPER} {key_hold_ms}")
    time.sleep(0.3)
    h.cmd("mouse_set 4")
    h.cmd(f"mouse_button {button}")
    time.sleep(0.3)
    for _ in range(steps):
        h.cmd(f"mouse_move {dx // steps} {dy // steps}")
        time.sleep(0.25)
    h.cmd("mouse_button 0")
    time.sleep(0.2)
    h.close()


def wheel(dz, steps=1):
    h = Hmp()
    h.cmd("mouse_set 4")
    for _ in range(steps):
        h.cmd(f"mouse_move 0 0 {dz}")
        time.sleep(0.25)
    h.close()


def move_to(dx, dy):
    h = Hmp()
    h.cmd("mouse_set 4")
    h.cmd(f"mouse_move {dx} {dy}")
    h.close()


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        selftest()
    elif args[0] == "cmd":
        run(args[1:])
    elif args[0] == "drag-super":
        drag_super(int(args[1]), int(args[2]), int(args[3]))
    elif args[0] == "wheel":
        wheel(int(args[1]), int(args[2]) if len(args) > 2 else 1)
    elif args[0] == "move":
        move_to(int(args[1]), int(args[2]))
    else:
        print(__doc__)
        sys.exit(1)
