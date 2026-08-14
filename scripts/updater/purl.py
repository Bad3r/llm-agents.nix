"""Package-URL (purl) parsing. Grammar: pkg:type/namespace/name@version?qualifiers#subpath.

Stdlib-only and imports nothing from updater.*: this parser is the seed of an
extractable, project-agnostic library, so keep it dependency-free. A purl is an
identity, not a locator; resolving it to a downloadable artifact is the fetcher's
job, which is why it layers x_* qualifier extensions on top of the bare identity.
Spec: https://github.com/package-url/purl-spec (PURL-SPECIFICATION.rst).
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from urllib.parse import quote, unquote


class PurlError(ValueError):
    """Raised when a string is not a well-formed purl."""


def _split_right(s: str, sep: str) -> tuple[str, str | None]:
    """Split once from the right; return (left, right-or-None)."""
    head, found, tail = s.rpartition(sep)
    return (head, tail) if found else (s, None)


def _decode_qualifiers(raw: str) -> dict[str, str]:
    """Parse a key=value&key=value qualifier string.

    Keys lowercased, values percent-decoded. Empty values are dropped: the spec
    treats a qualifier with an empty value as absent.
    """
    out: dict[str, str] = {}
    for pair in raw.split("&"):
        if not pair:
            continue
        key, _, value = pair.partition("=")
        key = key.strip().lower()
        if not key or value == "":
            continue
        out[key] = unquote(value)
    return out


def _decode_subpath(raw: str) -> str | None:
    """Normalize a subpath: strip slashes, drop '.'/'..', decode each segment."""
    segments = [
        unquote(seg) for seg in raw.strip("/").split("/") if seg not in ("", ".", "..")
    ]
    return "/".join(segments) or None


def _encode_qualifiers(qualifiers: dict[str, str]) -> str:
    # Canonical form sorts keys; encode values, not separators.
    parts = [
        f"{key}={quote(qualifiers[key], safe='')}"
        for key in sorted(qualifiers)
        if qualifiers[key] != ""
    ]
    return "&".join(parts)


@dataclass(frozen=True)
class Purl:
    """A parsed Package-URL.

    Fields are stored decoded (@zaly, not %40zaly); str(purl) re-encodes canonically.
    """

    type: str
    namespace: str | None
    name: str
    version: str | None = None
    qualifiers: dict[str, str] = field(default_factory=dict)
    subpath: str | None = None

    @classmethod
    def parse(cls, s: str) -> Purl:
        """Parse a purl string, splitting right-to-left per the spec.

        Order: subpath, qualifiers, scheme, then type/namespace/name@version.
        """
        if not isinstance(s, str) or not s.strip():
            msg = "purl must be a non-empty string"
            raise PurlError(msg)
        s = s.strip()

        remainder, subpath_raw = _split_right(s, "#")
        remainder, qualifiers_raw = _split_right(remainder, "?")

        scheme, sep, rest = remainder.partition(":")
        if not sep or scheme.lower() != "pkg":
            msg = f"purl must start with 'pkg:': {s!r}"
            raise PurlError(msg)

        # Spec allows leading slashes after pkg:; canonical form omits them.
        rest = rest.lstrip("/")
        type_part, sep, path = rest.partition("/")
        if not sep or not type_part:
            msg = f"purl is missing a type or name: {s!r}"
            raise PurlError(msg)
        ptype = type_part.lower()

        # Version rides on the final path segment, after the last '@'.
        path = path.strip("/")
        segments = [seg for seg in path.split("/") if seg != ""]
        if not segments:
            msg = f"purl is missing a name: {s!r}"
            raise PurlError(msg)

        last = segments.pop()
        name_raw, at, version_raw = last.rpartition("@")
        if not at:
            name_raw, version_raw = last, ""
        name = unquote(name_raw)
        if not name:
            msg = f"purl is missing a name: {s!r}"
            raise PurlError(msg)

        namespace = "/".join(unquote(seg) for seg in segments) or None
        version = unquote(version_raw) if version_raw else None
        qualifiers = _decode_qualifiers(qualifiers_raw) if qualifiers_raw else {}
        subpath = _decode_subpath(subpath_raw) if subpath_raw else None

        return cls(ptype, namespace, name, version, qualifiers, subpath)

    def with_version(self, version: str | None) -> Purl:
        """Return a copy pinned to ``version`` (or unpinned if None)."""
        return replace(self, version=version)

    def with_qualifiers(self, **extra: str) -> Purl:
        """Return a copy with additional qualifiers merged in."""
        merged = {
            **self.qualifiers,
            **{k: v for k, v in extra.items() if v is not None},
        }
        return replace(self, qualifiers=merged)

    def q(self, key: str, default: str | None = None) -> str | None:
        """Read a qualifier (e.g. ``x_tag_template``), or ``default``."""
        return self.qualifiers.get(key, default)

    def __str__(self) -> str:
        """Serialize to canonical purl form."""
        out = f"pkg:{self.type}"
        if self.namespace:
            encoded_ns = "/".join(
                quote(seg, safe="") for seg in self.namespace.split("/")
            )
            out += f"/{encoded_ns}"
        out += f"/{quote(self.name, safe='')}"
        if self.version:
            out += f"@{quote(self.version, safe='')}"
        if self.qualifiers:
            encoded = _encode_qualifiers(self.qualifiers)
            if encoded:
                out += f"?{encoded}"
        if self.subpath:
            encoded_sp = "/".join(
                quote(seg, safe="") for seg in self.subpath.split("/")
            )
            out += f"#{encoded_sp}"
        return out
