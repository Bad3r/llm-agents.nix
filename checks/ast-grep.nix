# Lint the Nix package definitions with ast-grep.
#
# Rules live in ../rules and are wired up via ../sgconfig.yml.  They catch
# anti-patterns that Nix evaluation alone won't reject, e.g. `rev = "v${...}"`
# for GitHub sources (prefer `tag`, see rules/prefer-tag-over-rev.yml).
{
  pkgs,
  flake,
  ...
}:
pkgs.runCommand "ast-grep-check"
  {
    nativeBuildInputs = [ pkgs.ast-grep ];
    src = flake;
  }
  ''
    cd "$src"
    ast-grep scan --error packages
    touch $out
  ''
