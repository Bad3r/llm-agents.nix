{ pkgs, perSystem }:
pkgs.mkShellNoCC {
  packages = [
    # Linter for package definitions (see rules/, sgconfig.yml)
    pkgs.ast-grep

    # Tools needed for update scripts
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.gh
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.nix-update
    pkgs.nodejs

    # Formatter
    perSystem.self.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
