{
  pkgs,
  flake,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit flake;
  autoPatchelfHook = perSystem.self.formatelf;
}
