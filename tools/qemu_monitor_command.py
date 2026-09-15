#!/usr/bin/env python3
"""Send one non-destructive command to an isolated QEMU monitor socket."""

import argparse
import socket
import sys


BLOCKED_PREFIXES = ("quit", "system_powerdown", "stop", "reset")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("socket", help="QEMU monitor Unix socket")
    parser.add_argument("command", nargs="+", help="one QEMU monitor command")
    args = parser.parse_args()
    command = " ".join(args.command)
    if command.split(maxsplit=1)[0] in BLOCKED_PREFIXES:
        parser.error("power/state commands are blocked by this helper")

    with socket.socket(socket.AF_UNIX) as monitor:
        monitor.settimeout(2.0)
        monitor.connect(args.socket)
        try:
            monitor.recv(4096)  # discard the monitor greeting
        except socket.timeout:
            pass
        # This is the monitor protocol terminator.  It is deliberately not
        # appended to a guest key event sent via `sendkey`.
        monitor.sendall((command + "\n").encode("utf-8"))
        output = bytearray()
        while True:
            try:
                chunk = monitor.recv(4096)
            except socket.timeout:
                break
            if not chunk:
                break
            output.extend(chunk)
    if output:
        sys.stdout.write(output.decode("utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
