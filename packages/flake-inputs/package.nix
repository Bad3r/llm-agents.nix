{
  inputs,
  pkgs,
}:
# References all flake inputs so they get cached.
pkgs.runCommand "flake-inputs" { } ''
  mkdir -p $out/nix-support
  echo ${pkgs.lib.concatMapStringsSep " " (name: inputs.${name}) (builtins.attrNames inputs)} \
    > $out/nix-support/flake-inputs
''
// {
  passthru.hideFromDocs = true;
}
