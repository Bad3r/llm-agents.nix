{
  lib,
  stdenv,
  platformSource,
  makeWrapper,
  wrapBuddy,
  gcc-unwrapped,
  versionCheckHook,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    };
    url =
      { version, platform }:
      "https://github.com/tailcallhq/forgecode/releases/download/v${version}/forge-${platform}";
  };
in
stdenv.mkDerivation rec {
  pname = "forgecode";
  inherit (source) version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/forge

    runHook postInstall
  '';

  # Forge phones home on every start and, if a newer release exists, runs
  # `curl -fsSL https://forgecode.dev/cli | sh` which drops a mutable copy
  # into ~/.local/bin and shadows the Nix-managed binary. Force the update
  # frequency to "never" so the store path stays authoritative.
  # https://github.com/numtide/llm-agents.nix/issues/5976
  postFixup = ''
    wrapProgram $out/bin/forge \
      --set-default FORGE_UPDATES__FREQUENCY never \
      --set-default FORGE_UPDATES__AUTO_UPDATE false
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "AI-Enhanced Terminal Development Environment - A comprehensive coding agent that integrates AI capabilities with your development environment";
    homepage = "https://github.com/tailcallhq/forgecode";
    changelog = "https://github.com/tailcallhq/forgecode/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ mic92 ];
    mainProgram = "forge";
    platforms = source.platforms;
  };
}
