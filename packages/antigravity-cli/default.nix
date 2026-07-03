{
  pkgs,
  perSystem,
  ...
}:
pkgs.callPackage ./package.nix {
  inherit (perSystem.self) versionCheckHomeHook;
  autoPatchelfHook = perSystem.self.formatelf;
}
