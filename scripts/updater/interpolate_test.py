"""Python side of the interpolate conformance contract.

Shares one fixture with lib/interpolate.nix; keep the two in lockstep.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from updater.interpolate import interpolate

_CASES = json.loads((Path(__file__).parent / "interpolate_cases.json").read_text())


class TestInterpolate(unittest.TestCase):
    def test_shared_cases(self) -> None:
        for case in _CASES:
            with self.subTest(case=case["name"]):
                got = interpolate(case["template"], case["vars"])
                self.assertEqual(got, case["expected"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
