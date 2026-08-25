{ pkgs }:
# pnpm's default 60s request timeout is too short for the large multi-platform
# dependency sets fetched here on slow links (#8291). Hash-neutral.
let
  inherit (pkgs) lib;
  networkConfig = ''
    pnpm config set fetch-timeout 600000
    pnpm config set fetch-retries 5
    pnpm config set fetch-retry-maxtimeout 120000
  '';
  wrap =
    args:
    pkgs.fetchPnpmDeps (
      args
      // {
        prePnpmInstall = networkConfig + (args.prePnpmInstall or "");
      }
    );
in
pkgs.emptyDirectory.overrideAttrs { name = "fetchPnpmDeps-wrapper"; }
// {
  __functor = _: wrap;
  passthru.hideFromDocs = true;
  meta = {
    description = "nixpkgs fetchPnpmDeps with longer fetch timeouts";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
