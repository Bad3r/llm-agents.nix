"""Tests for the state store and the dummy-build dependency hasher.

DepHasher takes an injected build command, so no Nix runs.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

from updater.deps import DepHasher
from updater.hash import DUMMY_SHA256_HASH
from updater.nix import NixCommandError
from updater.store import HashesJsonStore

_REAL = "sha256-cccccccccccccccccccccccccccccccccccccccccck="


class TestHashesJsonStore(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.path = Path(self._dir.name) / "hashes.json"
        self.path.write_text(
            json.dumps({"version": "1.0.0", "cargoHash": "sha256-old"})
        )

    def tearDown(self) -> None:
        self._dir.cleanup()

    def _on_disk(self) -> dict[str, Any]:
        loaded: dict[str, Any] = json.loads(self.path.read_text())
        return loaded

    def test_read_and_get(self) -> None:
        store = HashesJsonStore(self.path)
        self.assertEqual(store.read()["version"], "1.0.0")
        self.assertEqual(store.get("cargoHash"), "sha256-old")
        self.assertIsNone(store.get("absent"))

    def test_stage_and_commit_persist(self) -> None:
        store = HashesJsonStore(self.path)
        store.stage_dummy("cargoHash", DUMMY_SHA256_HASH)
        self.assertEqual(self._on_disk()["cargoHash"], DUMMY_SHA256_HASH)
        store.commit("cargoHash", _REAL)
        self.assertEqual(self._on_disk()["cargoHash"], _REAL)

    def test_rollback_to_original(self) -> None:
        store = HashesJsonStore(self.path)
        store.stage_dummy("cargoHash", DUMMY_SHA256_HASH)
        store.rollback("cargoHash", "sha256-old")
        self.assertEqual(self._on_disk()["cargoHash"], "sha256-old")

    def test_rollback_none_drops_key(self) -> None:
        store = HashesJsonStore(self.path)
        store.stage_dummy("vendorHash", DUMMY_SHA256_HASH)
        store.rollback("vendorHash", None)
        self.assertNotIn("vendorHash", self._on_disk())

    def test_wraps_in_memory_data(self) -> None:
        data = {"version": "2.0.0", "cargoHash": "x"}
        store = HashesJsonStore(self.path, data=data)
        store.commit("cargoHash", _REAL)
        # Mutates the caller's dict in place and persists it.
        self.assertEqual(data["cargoHash"], _REAL)
        self.assertEqual(self._on_disk()["cargoHash"], _REAL)


def _build_reports_hash(_attr: str, *, check: bool) -> None:
    _ = check
    msg = f"error: hash mismatch\n  specified: {DUMMY_SHA256_HASH}\n  got:    {_REAL}"
    raise NixCommandError(msg)


def _build_no_hash(_attr: str, *, check: bool) -> None:
    _ = check
    msg = "error: build failed for an unrelated reason"
    raise NixCommandError(msg)


def _build_succeeds(_attr: str, *, check: bool) -> None:
    _ = check


class TestDepHasher(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.path = Path(self._dir.name) / "hashes.json"
        self.path.write_text(
            json.dumps({"version": "1.0.0", "cargoHash": "sha256-old"})
        )

    def tearDown(self) -> None:
        self._dir.cleanup()

    def _disk(self) -> dict[str, Any]:
        loaded: dict[str, Any] = json.loads(self.path.read_text())
        return loaded

    def test_extracts_and_commits(self) -> None:
        store = HashesJsonStore(self.path)
        got = DepHasher(store, ".#pkg", build=_build_reports_hash).hash("cargoHash")
        self.assertEqual(got, _REAL)
        self.assertEqual(self._disk()["cargoHash"], _REAL)

    def test_no_hash_rolls_back_and_raises(self) -> None:
        store = HashesJsonStore(self.path)
        hasher = DepHasher(store, ".#pkg", build=_build_no_hash)
        with self.assertRaises(ValueError):
            hasher.hash("cargoHash")
        self.assertEqual(self._disk()["cargoHash"], "sha256-old")

    def test_unexpected_success_rolls_back_and_raises(self) -> None:
        store = HashesJsonStore(self.path)
        hasher = DepHasher(store, ".#pkg", build=_build_succeeds)
        with self.assertRaises(ValueError):
            hasher.hash("cargoHash")
        self.assertEqual(self._disk()["cargoHash"], "sha256-old")


if __name__ == "__main__":
    unittest.main(verbosity=2)
