{ pkgs, perSystem }:
pkgs.mkShellNoCC {
  packages = [
    # Tools needed for update scripts
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.gh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    # Pin nix-update 1.16.0 for buildDotnetModule fetch-deps flake support
    # (https://github.com/Mic92/nix-update/pull/615). Remove once nixpkgs catches up.
    (pkgs.nix-update.overrideAttrs (_: {
      version = "1.16.0";
      src = pkgs.fetchFromGitHub {
        owner = "Mic92";
        repo = "nix-update";
        rev = "v1.16.0";
        hash = "sha256-LT66e5NtAJRp0E8QXKeePdTCNpH+CMvJNF1ayzBr4rw=";
      };
    }))
    pkgs.nodejs

    # Formatter
    perSystem.self.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
