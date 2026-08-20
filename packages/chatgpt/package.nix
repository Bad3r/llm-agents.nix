{
  lib,
  callPackage,
  stdenvNoCC,
  makeShellWrapper,
  chatgpt-unwrapped ? callPackage ./unwrapped.nix { },
  commandLineArgs ? "",
}:

stdenvNoCC.mkDerivation {
  pname = "chatgpt";
  inherit (chatgpt-unwrapped) version;

  dontUnpack = true;

  nativeBuildInputs = [ makeShellWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    makeShellWrapper ${chatgpt-unwrapped}/bin/chatgpt "$out/bin/chatgpt" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland}}" \
      --add-flags ${lib.escapeShellArg commandLineArgs}
    ln -s ${chatgpt-unwrapped}/share "$out/share"

    runHook postInstall
  '';

  passthru = {
    category = "AI Coding Agents";
    unwrapped = chatgpt-unwrapped;
  };

  inherit (chatgpt-unwrapped) meta;
}
