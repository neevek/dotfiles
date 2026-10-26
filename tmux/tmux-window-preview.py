#!/usr/bin/env python3
"""Preview a window's active pane, preserving syntax colors on a uniform background."""

import os
import re
import subprocess
import sys


BACKGROUND_CODES = {str(n) for n in range(40, 50)} | {str(n) for n in range(100, 108)}

def without_background(match):
    """Remove only SGR background colors, retaining foreground and text styles."""
    fields = match.group(1).split(';')
    kept = []
    i = 0
    while i < len(fields):
        field = fields[i]
        code = field.split(':', 1)[0]
        if code == '48':
            if ':' not in field and i + 1 < len(fields):
                mode = fields[i + 1]
                i += {'5': 2, '2': 4}.get(mode, 0)
        elif code not in BACKGROUND_CODES:
            kept.append(field)
        i += 1
    return '\033[' + ';'.join(kept) + 'm' if kept else ''


def main():
    target = sys.argv[1]
    try:
        # Resolve once: a window's active pane may change while the picker is open.
        info = subprocess.check_output(
            ['tmux', 'display-message', '-p', '-t', target, '#{pane_id} #{pane_height}'],
            text=True, stderr=subprocess.DEVNULL,
        )
        pane, height = info.split()
        lines = max(1, int(os.environ.get('FZF_PREVIEW_LINES', height)))
        start = max(0, int(height) - lines)
        output = subprocess.check_output(
            ['tmux', 'capture-pane', '-p', '-e', '-t', pane, '-S', str(start)],
            stderr=subprocess.DEVNULL,
        ).decode('utf-8', errors='replace')
    except (subprocess.CalledProcessError, ValueError):
        return
    # Capture the range directly: tail would discard preceding ANSI color state.
    output = re.sub(r'\x1b\[([0-9;:]*)m', without_background, output)
    sys.stdout.write('\033[0m' + output + '\033[0m')


if __name__ == '__main__':
    main()
