{
  pkgs,
  flake,
  perSystem,
  disableTelemetry ? false,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  inherit (perSystem.self) wrapBuddy;
  inherit disableTelemetry;
}
