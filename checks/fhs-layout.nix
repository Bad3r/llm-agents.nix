# Only FHS-like directories may sit directly under $out; anything else ends up
# at the top level of buildEnv/home-manager profiles and collides (#9364).
{
  pkgs,
  flake,
  system,
  ...
}:

let
  inherit (pkgs) lib;
  allowed = "bin sbin lib lib64 libexec share include etc opt Applications nix-support";
  packages = flake.packages.${system} or { };
in
pkgs.runCommand "fhs-layout" { } ''
  status=0
  ${lib.concatMapStrings (name: ''
    strays=$(ls -A ${packages.${name}} | grep -vxF ${
      lib.escapeShellArg (lib.replaceStrings [ " " ] [ "\n" ] allowed)
    } || true)
    if [ -n "$strays" ]; then
      echo "${name}: $strays"
      status=1
    fi
  '') (lib.attrNames packages)}
  [ "$status" = 0 ] || { echo "allowed in \$out: ${allowed} (see AGENTS.md, Output Layout)"; exit 1; }
  touch $out
''
