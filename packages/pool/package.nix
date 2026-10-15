{
  lib,
  flake,
  stdenv,
  platformSource,
  versionCheckHook,
  versionCheckHomeHook,
  codesignCheckHook,
  mkUpdater,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://github.com/poolsideai/pool/releases/download/v{version}/pool-{platform}.tar.gz";
  };
  inherit (source) version;

  # The tarball holds one binary named pool-<platform>.
  platformSuffix = source.updater.platforms.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "pool";
  inherit (source) version src;

  sourceRoot = ".";

  # Stripping would break the macOS code signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 pool-${platformSuffix} $out/bin/pool
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
    codesignCheckHook
  ];
  codesignTeamId = "SDHHA3W3SF";
  codesignSources = source.darwinSrcs;

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "poolsideai";
        repo = "pool";
      };
    }
  );

  meta = with lib; {
    description = "Poolside's coding agent";
    homepage = "https://poolside.ai";
    changelog = "https://github.com/poolsideai/pool/releases/tag/v${version}";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ flake.lib.maintainers.wtf9880 ];
    mainProgram = "pool";
    platforms = source.platforms;
  };
}
