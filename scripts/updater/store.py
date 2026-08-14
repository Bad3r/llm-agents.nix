"""Where a resolved version and its hashes are persisted.

``StateStore`` is the seam that decouples the dummy-build hash dance from
``hashes.json``, so a repo keeping ``cargoHash`` inline can reuse it too.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any, Protocol, runtime_checkable

from .hashes_file import load_hashes, save_hashes

if TYPE_CHECKING:
    from pathlib import Path


@runtime_checkable
class StateStore(Protocol):
    """Read the current pin and write a new one.

    ``stage_dummy`` / ``rollback`` / ``commit`` drive the hash round-trip: stage
    a placeholder, build (expected to fail), then commit the real hash or roll
    back.
    """

    def read(self) -> dict[str, Any]:
        """Return the current persisted state."""
        ...

    def write(self, data: dict[str, Any]) -> None:
        """Replace the persisted state wholesale."""
        ...

    def get(self, key: str) -> str | None:
        """Return one key's value, or None if absent."""
        ...

    def stage_dummy(self, key: str, dummy: str) -> None:
        """Persist a placeholder hash so a build fails with the real one."""
        ...

    def rollback(self, key: str, original: str | None) -> None:
        """Restore a key to its pre-staging value."""
        ...

    def commit(self, key: str, value: str) -> None:
        """Persist the final value of one key."""
        ...


class HashesJsonStore:
    """A ``hashes.json`` sidecar next to ``package.nix``.

    Wraps an existing ``data`` dict rather than re-reading the file, so a flow
    that just built ``data`` keeps mutating the same object.
    """

    def __init__(self, path: Path, *, data: dict[str, Any] | None = None) -> None:
        """Open the store, optionally around an in-memory ``data`` dict."""
        self._path = path
        self._data = data if data is not None else load_hashes(path)

    def read(self) -> dict[str, Any]:
        """Return the in-memory state."""
        return self._data

    def write(self, data: dict[str, Any]) -> None:
        """Replace and persist the whole state."""
        self._data = data
        save_hashes(self._path, self._data)

    def get(self, key: str) -> str | None:
        """Return one key's value, or None."""
        value = self._data.get(key)
        return value if isinstance(value, str) else None

    def stage_dummy(self, key: str, dummy: str) -> None:
        """Write a placeholder hash and persist."""
        self._set(key, dummy)

    def rollback(self, key: str, original: str | None) -> None:
        """Restore the pre-staging value, dropping the key if it was absent."""
        if original is None:
            self._data.pop(key, None)
            save_hashes(self._path, self._data)
        else:
            self._set(key, original)

    def commit(self, key: str, value: str) -> None:
        """Write the final value and persist."""
        self._set(key, value)

    def _set(self, key: str, value: str) -> None:
        self._data[key] = value
        save_hashes(self._path, self._data)
