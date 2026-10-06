#!/usr/bin/env python3
"""Length-preserving edit to the JS payload embedded in the cortex binary:
default --auto-update to false.
"""

import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_bytes()

old = (
    b'description:"Auto-update on launch (use --no-auto-update to disable)",default:!0}'
)
if data.count(old) != 1:
    sys.exit("auto-update option not found exactly once")
data = data.replace(old, old[:-2] + b"1}")

path.write_bytes(data)
