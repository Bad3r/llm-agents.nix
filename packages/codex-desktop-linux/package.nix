{
  flake,
  lib,
  pkgs,
}:

let
  input = flake.inputs.codex-desktop-linux;
  system = pkgs.stdenv.hostPlatform.system;
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  package =
    input.packages.${system}.codex-desktop or (pkgs.runCommand "codex-desktop-linux-unsupported" { } ''
      mkdir "$out"
    '');
in
builtins.removeAttrs package [ "version" ]
// {
  passthru = (package.passthru or { }) // {
    category = "AI Assistants";
  };

  meta = package.meta // {
    description = "Unofficial Linux build of ChatGPT Desktop";
    homepage = "https://github.com/ilysenko/codex-desktop-linux";
    changelog = "https://github.com/ilysenko/codex-desktop-linux/blob/${input.rev}/CHANGELOG.md";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      binaryBytecode
    ];
    maintainers = with flake.lib.maintainers; [ Bad3r ];
    platforms = supportedSystems;
    mainProgram = "codex-desktop";
  };
}
