"""Tests for the update entry point."""

import unittest

from update import refuse_downgrade


class TestRefuseDowngrade(unittest.TestCase):
    def test_upgrades_and_unchanged_versions_pass(self) -> None:
        refuse_downgrade("qwen-code", "0.24.1", "0.25.1")
        refuse_downgrade("qwen-code", "0.24.1", "0.24.1")
        refuse_downgrade("oh-my-opencode", "5.0.0-beta.86", "5.0.0")

    def test_downgrade_fails(self) -> None:
        with self.assertRaises(SystemExit):
            refuse_downgrade("qwen-code", "0.24.1", "0.21.2")


if __name__ == "__main__":
    unittest.main()
