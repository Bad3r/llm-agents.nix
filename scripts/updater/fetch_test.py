"""Tests for the purl fetcher core and the five handlers.

Network is faked via fake_deps, so discovery and location building run offline.
"""

from __future__ import annotations

import unittest
from typing import Any

from updater.fetch import (
    Deps,
    Location,
    MissingQualifierError,
    PurlFetcher,
    Resolved,
    UnknownPlatformMapError,
    UnknownPurlTypeError,
    VersionPolicy,
    apply_tag_template,
    resolve_platform_map,
    strip_tag_template,
    templated_locations,
)
from updater.handlers import (
    CargoHandler,
    GenericHandler,
    GiteaHandler,
    GithubHandler,
    NpmHandler,
)
from updater.purl import Purl

Json = dict[str, Any] | list[Any]


def fake_deps(
    *,
    json_routes: dict[str, Json] | None = None,
    text_routes: dict[str, str] | None = None,
) -> Deps:
    """Build a Deps whose fetchers match the first route key that is a substring."""
    jr = json_routes or {}
    tr = text_routes or {}

    def fetch_json(url: str) -> Json:
        for key, value in jr.items():
            if key in url:
                return value
        msg = f"no fake json route for {url}"
        raise AssertionError(msg)

    def fetch_text(url: str) -> str:
        for key, value in tr.items():
            if key in url:
                return value
        msg = f"no fake text route for {url}"
        raise AssertionError(msg)

    def hash_url(url: str, *, unpack: bool = False) -> str:
        return f"sha256-FAKE({url},unpack={unpack})"

    return Deps(fetch_json=fetch_json, fetch_text=fetch_text, hash_url=hash_url)


class TestVersionPolicy(unittest.TestCase):
    def test_semver_picks_highest(self) -> None:
        p = VersionPolicy(kind="semver")
        self.assertEqual(p.select(["1.2.0", "1.10.0", "1.9.0"]), "1.10.0")

    def test_prerelease_exclude(self) -> None:
        p = VersionPolicy(kind="prerelease_exclude")
        self.assertEqual(p.select(["1.0.0", "1.1.0-rc1", "1.1.0-beta"]), "1.0.0")

    def test_prerelease_exclude_can_empty(self) -> None:
        p = VersionPolicy(kind="prerelease_exclude")
        self.assertIsNone(p.select(["2.0.0-rc1"]))

    def test_regex_filter(self) -> None:
        p = VersionPolicy(kind="regex_filter", regex=r"1\.2\.\d+")
        self.assertEqual(p.select(["1.2.3", "1.3.0", "1.2.9"]), "1.2.9")

    def test_follow_pointer_takes_first(self) -> None:
        p = VersionPolicy(kind="follow_pointer")
        self.assertEqual(p.select(["0.9.0", "5.0.0"]), "0.9.0")

    def test_follow_pointer_allows_downgrade(self) -> None:
        p = VersionPolicy(kind="follow_pointer")
        self.assertTrue(p.should_write("1.2.0", "1.1.0"))
        self.assertFalse(p.should_write("1.1.0", "1.1.0"))

    def test_semver_requires_increase(self) -> None:
        p = VersionPolicy(kind="semver")
        self.assertFalse(p.should_write("1.2.0", "1.1.0"))
        self.assertTrue(p.should_write("1.1.0", "1.2.0"))

    def test_date_suffix_not_prerelease(self) -> None:
        p = VersionPolicy(kind="prerelease_exclude")
        self.assertEqual(p.select(["0.1.44-20260424091429"]), "0.1.44-20260424091429")


class TestTagTemplates(unittest.TestCase):
    def test_apply(self) -> None:
        self.assertEqual(apply_tag_template("rust-v{v}", "1.2.3"), "rust-v1.2.3")
        self.assertEqual(apply_tag_template("{v}", "1.2.3"), "1.2.3")

    def test_strip(self) -> None:
        self.assertEqual(strip_tag_template("v1.2.3", "v{v}"), "1.2.3")
        self.assertEqual(strip_tag_template("rust-v1.2.3", "rust-v{v}"), "1.2.3")
        self.assertEqual(strip_tag_template("icm-v9.9", "icm-v{v}"), "9.9")
        self.assertEqual(strip_tag_template("1.2.3", "{v}"), "1.2.3")


class TestPlatformMaps(unittest.TestCase):
    def test_string_tokens_normalized(self) -> None:
        # A string token normalizes to the {platform} var.
        p = Purl.parse(
            'pkg:generic/go?x_platforms={"x86_64-linux":"linux-amd64",'
            '"aarch64-linux":"linux-arm64","aarch64-darwin":"darwin-arm64"}'
        )
        m = resolve_platform_map(p)
        self.assertEqual(m["x86_64-linux"], {"platform": "linux-amd64"})
        self.assertEqual(len(m), 3)

    def test_inline_json_map(self) -> None:
        p = Purl.parse('pkg:generic/x?x_platforms={"x86_64-linux":"amd64"}')
        self.assertEqual(
            resolve_platform_map(p), {"x86_64-linux": {"platform": "amd64"}}
        )

    def test_multivar_map(self) -> None:
        # An object entry supplies arbitrary vars (os/cpu) for the URL.
        p = Purl.parse(
            'pkg:generic/x?x_platforms={"x86_64-linux":{"os":"linux","cpu":"x86_64"}}'
        )
        self.assertEqual(
            resolve_platform_map(p),
            {"x86_64-linux": {"os": "linux", "cpu": "x86_64"}},
        )

    def test_multivar_fanout(self) -> None:
        p = Purl.parse(
            "pkg:generic/swamp"
            '?x_platforms={"x86_64-linux":{"os":"linux","cpu":"x86_64"},'
            '"aarch64-darwin":{"os":"darwin","cpu":"aarch64"}}'
        )
        r = Resolved(version="1.2.3", ref="1.2.3")
        locs = templated_locations(
            p, r, "https://h/{version}/swamp-{version}-{os}-{cpu}.tar.gz"
        )
        urls = {loc.component: loc.url for loc in locs}
        self.assertEqual(
            urls["x86_64-linux"], "https://h/1.2.3/swamp-1.2.3-linux-x86_64.tar.gz"
        )
        self.assertEqual(
            urls["aarch64-darwin"], "https://h/1.2.3/swamp-1.2.3-darwin-aarch64.tar.gz"
        )

    def test_no_map(self) -> None:
        self.assertEqual(resolve_platform_map(Purl.parse("pkg:generic/x")), {})

    def test_unknown_map_raises(self) -> None:
        p = Purl.parse("pkg:generic/x?x_platforms=nopeMap")
        with self.assertRaises(UnknownPlatformMapError):
            resolve_platform_map(p)

    def test_templated_fanout(self) -> None:
        p = Purl.parse(
            'pkg:generic/go?x_platforms={"x86_64-linux":"linux-amd64",'
            '"aarch64-linux":"linux-arm64","aarch64-darwin":"darwin-arm64"}'
        )
        r = Resolved(version="1.22.0", ref="1.22.0")
        locs = templated_locations(
            p, r, "https://go.dev/dl/go{version}.{platform}.tar.gz"
        )
        urls = {loc.component: loc.url for loc in locs}
        self.assertEqual(len(urls), 3)
        self.assertEqual(
            urls["x86_64-linux"], "https://go.dev/dl/go1.22.0.linux-amd64.tar.gz"
        )


class TestGithubHandler(unittest.TestCase):
    def test_semver_release(self) -> None:
        h = GithubHandler(
            fake_deps(json_routes={"releases/latest": {"tag_name": "v1.4.0"}})
        )
        r = h.latest_version(Purl.parse("pkg:github/openai/codex"), VersionPolicy())
        self.assertEqual((r.version, r.ref), ("1.4.0", "v1.4.0"))

    def test_tag_template_strip(self) -> None:
        h = GithubHandler(
            fake_deps(json_routes={"releases/latest": {"tag_name": "rust-v2.0.0"}})
        )
        p = Purl.parse("pkg:github/openai/codex?x_tag_template=rust-v%7Bv%7D")
        r = h.latest_version(p, VersionPolicy())
        self.assertEqual((r.version, r.ref), ("2.0.0", "rust-v2.0.0"))

    def test_prerelease_exclude_uses_list(self) -> None:
        routes: dict[str, Any] = {
            "releases?per_page": [{"tag_name": "v2.0.0-rc1"}, {"tag_name": "v1.9.0"}]
        }
        h = GithubHandler(fake_deps(json_routes=routes))
        p = Purl.parse("pkg:github/o/r")
        r = h.latest_version(p, VersionPolicy(kind="prerelease_exclude"))
        self.assertEqual(r.version, "1.9.0")

    def test_source_tarball_location(self) -> None:
        h = GithubHandler(fake_deps())
        locs = h.locations(
            Purl.parse("pkg:github/openai/codex"),
            Resolved(version="1.4.0", ref="v1.4.0"),
        )
        self.assertEqual(len(locs), 1)
        self.assertEqual(
            locs[0].url,
            "https://github.com/openai/codex/archive/refs/tags/v1.4.0.tar.gz",
        )
        self.assertTrue(locs[0].unpack)

    def test_release_asset_matrix(self) -> None:
        h = GithubHandler(fake_deps())
        p = Purl.parse(
            "pkg:github/cjpais/Handy"
            '?x_platforms={"x86_64-linux":"linux-x64","aarch64-linux":"linux-arm64",'
            '"aarch64-darwin":"darwin-arm64"}'
            "&x_download_url=https://github.com/cjpais/Handy/releases/download/"
            "v%7Bversion%7D/handy-%7Bplatform%7D.tar.gz"
        )
        locs = h.locations(p, Resolved(version="0.3.0", ref="v0.3.0"))
        urls = {loc.component: loc.url for loc in locs}
        self.assertEqual(len(urls), 3)
        self.assertIn("handy-darwin-arm64.tar.gz", urls["aarch64-darwin"])


class TestNpmHandler(unittest.TestCase):
    def test_scoped_version(self) -> None:
        h = NpmHandler(
            fake_deps(json_routes={"registry.npmjs.org": {"version": "3.1.0"}})
        )
        r = h.latest_version(Purl.parse("pkg:npm/%40zaly/cli"), VersionPolicy())
        self.assertEqual(r.version, "3.1.0")

    def test_scoped_tarball_url(self) -> None:
        h = NpmHandler(fake_deps())
        locs = h.locations(
            Purl.parse("pkg:npm/%40zaly/cli"), Resolved(version="3.1.0", ref="3.1.0")
        )
        self.assertEqual(
            locs[0].url, "https://registry.npmjs.org/@zaly/cli/-/cli-3.1.0.tgz"
        )

    def test_unscoped_tarball_url(self) -> None:
        h = NpmHandler(fake_deps())
        locs = h.locations(
            Purl.parse("pkg:npm/skills"), Resolved(version="1.0.0", ref="1.0.0")
        )
        self.assertEqual(
            locs[0].url, "https://registry.npmjs.org/skills/-/skills-1.0.0.tgz"
        )


class TestCargoHandler(unittest.TestCase):
    def test_skips_yanked_and_picks_highest(self) -> None:
        crate: dict[str, Any] = {
            "versions": [
                {"num": "1.0.0", "yanked": False},
                {"num": "1.2.0", "yanked": True},
                {"num": "1.1.0", "yanked": False},
            ]
        }
        h = CargoHandler(fake_deps(json_routes={"crates.io/api": crate}))
        r = h.latest_version(Purl.parse("pkg:cargo/ripgrep"), VersionPolicy())
        self.assertEqual(r.version, "1.1.0")

    def test_crate_location(self) -> None:
        h = CargoHandler(fake_deps())
        locs = h.locations(
            Purl.parse("pkg:cargo/ripgrep"), Resolved(version="1.1.0", ref="1.1.0")
        )
        self.assertEqual(
            locs[0].url,
            "https://static.crates.io/crates/ripgrep/ripgrep-1.1.0.crate",
        )


class TestGiteaHandler(unittest.TestCase):
    def test_release_and_archive(self) -> None:
        h = GiteaHandler(fake_deps(json_routes={"/releases": [{"tag_name": "v4.5.6"}]}))
        p = Purl.parse("pkg:gitea/swamp-club/swamp?x_host=https://gitea.example.com")
        r = h.latest_version(p, VersionPolicy())
        self.assertEqual((r.version, r.ref), ("4.5.6", "v4.5.6"))
        locs = h.locations(p, r)
        self.assertEqual(
            locs[0].url,
            "https://gitea.example.com/swamp-club/swamp/archive/v4.5.6.tar.gz",
        )

    def test_missing_host_raises(self) -> None:

        h = GiteaHandler(fake_deps())
        with self.assertRaises(MissingQualifierError):
            h.latest_version(Purl.parse("pkg:gitea/o/r"), VersionPolicy())


class TestGenericHandler(unittest.TestCase):
    def test_text_pointer_version(self) -> None:
        h = GenericHandler(fake_deps(text_routes={"version.txt": 'tag: "7.8.9"\n'}))
        p = Purl.parse(
            "pkg:generic/grok"
            "?x_version_url=https://example.com/version.txt"
            "&x_version_regex=tag:%20%22%28%5B%5E%22%5D%2B%29%22"
        )
        r = h.latest_version(p, VersionPolicy())
        self.assertEqual(r.version, "7.8.9")

    def test_download_matrix(self) -> None:
        h = GenericHandler(fake_deps())
        p = Purl.parse(
            "pkg:generic/go"
            '?x_platforms={"x86_64-linux":"linux-amd64","aarch64-linux":"linux-arm64",'
            '"aarch64-darwin":"darwin-arm64"}'
            "&x_download_url=https://go.dev/dl/go%7Bversion%7D.%7Bplatform%7D.tar.gz"
        )
        locs = h.locations(p, Resolved(version="1.22.0", ref="1.22.0"))
        self.assertEqual(len(locs), 3)

    def test_missing_download_url_raises(self) -> None:

        h = GenericHandler(fake_deps())
        with self.assertRaises(MissingQualifierError):
            h.locations(Purl.parse("pkg:generic/x"), Resolved(version="1", ref="1"))


class TestSourceHash(unittest.TestCase):
    def test_prefetch_path(self) -> None:
        h = GithubHandler(fake_deps())
        got = h.source_hash(Location("src", "https://x/y.tar.gz", unpack=True))
        self.assertEqual(got, "sha256-FAKE(https://x/y.tar.gz,unpack=True)")

    def test_upstream_checksum_path(self) -> None:
        h = GithubHandler(fake_deps())
        # 32 zero bytes -> known SRI, no network.
        got = h.source_hash(Location("src", "https://x", upstream_sha="00" * 32))
        self.assertEqual(got, "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")


class TestFetcherDispatch(unittest.TestCase):
    def test_unknown_type_raises(self) -> None:
        fetcher = PurlFetcher.default(fake_deps())
        with self.assertRaises(UnknownPurlTypeError):
            fetcher.resolve(Purl.parse("pkg:pypi/requests"))

    def test_resolve_locate_hashes_wire_through(self) -> None:
        fetcher = PurlFetcher.default(
            fake_deps(json_routes={"releases/latest": {"tag_name": "v1.0.0"}})
        )
        purl = Purl.parse("pkg:github/openai/codex")
        resolved = fetcher.resolve(purl)
        self.assertEqual(resolved.version, "1.0.0")
        hashes = fetcher.hashes(purl, resolved)
        self.assertIn("src", hashes)
        self.assertTrue(hashes["src"].startswith("sha256-FAKE("))

    def test_default_registers_all_handlers(self) -> None:
        fetcher = PurlFetcher.default(fake_deps())
        for pt in ("github", "npm", "generic", "cargo", "gitea"):
            self.assertEqual(fetcher.handler(Purl.parse(f"pkg:{pt}/o/n")).purl_type, pt)


if __name__ == "__main__":
    unittest.main(verbosity=2)
