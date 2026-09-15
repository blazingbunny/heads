#!/usr/bin/env python3
"""Send one safe full-line command to an isolated QEMU serial socket."""

import argparse
import socket
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("socket", help="QEMU serial Unix socket")
    parser.add_argument("command", nargs="+", help="one full-line guest command")
    args = parser.parse_args()
    command = " ".join(args.command)
    if any(ord(char) < 0x20 and char not in "\t\n\r" for char in command):
        parser.error("control characters are blocked; send a full line only")

    with socket.socket(socket.AF_UNIX) as serial:
        serial.settimeout(2.0)
        serial.connect(args.socket)
        serial.sendall((command.rstrip("\r\n") + "\n").encode("utf-8"))
        output = bytearray()
        while True:
            try:
                chunk = serial.recv(4096)
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
