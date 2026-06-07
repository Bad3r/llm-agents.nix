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
  version = "2.1.4";
  src = pkgs.fetchFromGitHub {
    owner = "dolthub";
    repo = "dolt";
    rev = "v${version}";
    hash = "sha256-0AyKwejOvTMgt53B22D0EIWuAwB/6QxxTHd0S77Fu1M=";
  };
  vendorHash = "sha256-tKkXZdbNFxyVK76aNkNDM3/s3e6J7aqLvAnA+jQBSNg=";
  passthru = (old.passthru or { }) // {
    hideFromDocs = true;
    updateEvenIfHidden = true;
  };
}))
