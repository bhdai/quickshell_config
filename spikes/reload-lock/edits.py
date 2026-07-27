"""Reload triggers for the spike, applied as in-place rewrites.

In-place matters: Quickshell's file watcher did not fire for `touch` (mtime only)
or for `sed -i` (which replaces the file by rename). Only rewriting the existing
inode's contents reliably triggered a reload.
"""

import sys


def read(path):
    return open(path).read()


def write(path, src):
    open(path, "w").write(src)


def nudge(path):
    """Smallest possible successful reload: append a comment."""
    write(path, read(path) + "\n// reload nudge\n")


def syntax_error(path):
    write(path, read(path) + "\n} // deliberate syntax error\n")


def set_knob(path, old, new):
    src = read(path)
    assert old in src, f"knob {old!r} not found in {path}"
    write(path, src.replace(old, new))


def reorder(path):
    """Swap two Reloadable siblings so their index positions under ShellRoot change."""
    lines = read(path).split("\n")

    def block(head):
        i = lines.index(head)
        j = i + 1
        while lines[j] != "    }":
            j += 1
        return i, j + 1

    start, end = block("    IpcHandler {")
    ipc = lines[start:end]
    rest = lines[:start] + lines[end:]
    target = rest.index("    WlSessionLock {")
    write(path, "\n".join(rest[:target] + ipc + [""] + rest[target:]))


def sibling_above(path):
    """A developer adding a top-level item above the lock module in shell.qml."""
    anchor = "    LockModule {}"
    src = read(path)
    assert anchor in src
    write(path, src.replace(anchor, "    Scope {}\n" + anchor))


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    {
        "nudge": nudge,
        "syntax-error": syntax_error,
        "set-knob": set_knob,
        "reorder": reorder,
        "sibling-above": sibling_above,
    }[cmd](*args)
