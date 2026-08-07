# Merge the bridge (root) and web UI lockfiles into one bun package set so
# a single fetchBunDeps cache serves both `bun install` runs.  The formal
# args must be spelled out: callPackage only injects declared arguments.
{
  copyPathToStore,
  fetchFromGitHub,
  fetchgit,
  fetchurl,
  ...
}:
let
  args = {
    inherit
      copyPathToStore
      fetchFromGitHub
      fetchgit
      fetchurl
      ;
  };
in
(import ./bun.nix args) // (import ./web-bun.nix args)
