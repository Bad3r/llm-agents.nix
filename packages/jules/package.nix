{
  lib,
  flake,
  stdenv,
  platformSource,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux_amd64";
      aarch64-linux = "linux_arm64";
      aarch64-darwin = "darwin_arm64";
    };
    url =
      { version, platform }:
      "https://storage.googleapis.com/jules-cli/v${version}/jules_external_v${version}_${platform}.tar.gz";
  };
in
stdenv.mkDerivation {
  pname = "jules";
  inherit (source) version src;

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  # The tarball extracts to a directory with jules binary and licenses/ subdirectory
  # Explicitly set sourceRoot to prevent Nix from picking licenses/ as the source
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 jules $out/bin/jules

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  # Jules uses "version" subcommand, not --version flag
  versionCheckProgramArg = [ "version" ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Jules, the asynchronous coding agent from Google, in the terminal";
    homepage = "https://jules.google";
    changelog = "https://jules.google/docs/changelog";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "jules";
    platforms = source.platforms;
  };
}
