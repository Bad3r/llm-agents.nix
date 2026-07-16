# nixpkgs ships dolt 1.x, but gascity's managed bd/Dolt runtime requires
# Dolt >= 2.1.0. Bump the nixpkgs package; dolt 2.1.2 requires go >= 1.26.2,
# newer than nixpkgs' default Go, so build with go-bin.
{ pkgs, perSystem, ... }:
let
  base = pkgs.dolt.override {
    buildGoModule = pkgs.buildGoModule.override { go = perSystem.self.go-bin; };
  };
in
(base.overrideAttrs (old: rec {
  version = "2.2.0";
  src = pkgs.fetchFromGitHub {
    owner = "dolthub";
    repo = "dolt";
    tag = "v${version}";
    hash = "sha256-Wisa9ej5IGf4pXeePw1pDAGxeU3gf4aRCAbHXTC271g=";
  };
  vendorHash = "sha256-mvoy/ChZVGG9QxRGUG902Eda37SuJGjYLOi87OqjF68=";
  passthru = (old.passthru or { }) // {
    hideFromDocs = true;
    updateEvenIfHidden = true;
  };
}))
