{
  pkgs,
  flake,
  system,
  ...
}:

let
  packages = flake.packages.${system};
  t3code = packages.t3code;
  desktop = packages.t3code-desktop;
in
assert t3code.meta.mainProgram == "t3";
assert desktop.meta.mainProgram == "t3code-desktop";
assert !(desktop ? version);
assert t3code.passthru ? resourceMonitor;
assert pkgs.lib.hasInfix "package.json').dependencies.electron" (
  builtins.readFile ../packages/t3code/package.nix
);
assert map pkgs.lib.getName t3code.passthru.providerPackages == [
  "grok"
  "claude-code"
  "codex"
  "opencode"
  "cursor-agent"
];
pkgs.runCommand "t3code-packaging-check" { } ''
  touch $out
''
