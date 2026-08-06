#!/usr/bin/env python3
"""Fire a Hyprland batch the instant a marker appears in a log file.

Spawning hyprctl costs ~90ms, which overshoots the race window this reproduces.
Connecting to the request socket up front and writing on the marker costs ~1ms.

    trigger.py <sig> <logfile> <marker> <batch-command>
"""
import os
import socket
import sys
import time

sig, logfile, marker, batch = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
path = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{sig}/.socket.sock"

# Hyprland closes an idle request connection, so connect on the marker rather than up
# front. A unix-socket connect costs tens of microseconds; spawning hyprctl costs ~90ms,
# which is what overshot the window.
deadline = time.time() + 30
while time.time() < deadline:
    try:
        with open(logfile, "rb") as f:
            if marker.encode() in f.read():
                break
    except FileNotFoundError:
        pass
    time.sleep(0.0005)
else:
    print("marker never appeared", file=sys.stderr)
    sys.exit(1)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(path)
sock.sendall(f"[[BATCH]]{batch}".encode())
print(f"sent at {time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d}")
print(sock.recv(8192).decode(errors="replace"))
