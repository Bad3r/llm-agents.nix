# ctranslate2 4.8.1 (NixOS/nixpkgs#538070) ships a fetchSubmodules hash that
# does not reproduce; the real hash of the v4.8.1 tree with submodules is the
# one below. The Python module receives the C library as ctranslate2-cpp =
# pkgs.ctranslate2 (passed inline, not a member of the python set), so the fix
# has to land on the top-level attribute. Consumers apply it via pkgs.extend to
# scope the rebuild instead of using a global overlay.
#
# Already fixed on nixpkgs master (commit a4c0db72241f, "ctranslate2: fix src
# hash") but not yet in the nixpkgs-unstable channel this flake tracks. Drop
# this overlay once that fix reaches nixpkgs-unstable.
_final: prev: {
  ctranslate2 = prev.ctranslate2.overrideAttrs (old: {
    src = old.src.overrideAttrs (_: {
      outputHash = "sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=";
    });
  });
}
