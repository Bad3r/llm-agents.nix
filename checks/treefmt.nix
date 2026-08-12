# Run treefmt over the tree and fail on any diff. `nix fmt` was only a
# convention until now: the flake checks never ran the formatter, so
# formatting drift and ast-grep rule violations sailed through CI and
# surfaced on the next contributor's `nix fmt`.
{
  pkgs,
  flake,
  system,
}:
pkgs.runCommand "treefmt-check"
  {
    nativeBuildInputs = [ flake.packages.${system}.formatter ];
  }
  ''
    cp -r ${flake} source
    chmod -R +w source
    cd source
    HOME=$TMPDIR treefmt --no-cache --fail-on-change
    touch $out
  ''
