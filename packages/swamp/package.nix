{
  lib,
  flake,
  stdenv,
  platformSource,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
  mkUpdater,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = {
        os = "linux";
        cpu = "x86_64";
      };
      aarch64-linux = {
        os = "linux";
        cpu = "aarch64";
      };
      aarch64-darwin = {
        os = "darwin";
        cpu = "aarch64";
      };
    };
    urlTemplate = "https://artifacts.swamp-club.com/swamp/{version}/binary/{os}/{cpu}/swamp-{version}-binary-{os}-{cpu}.tar.gz";
  };
in
stdenv.mkDerivation {
  pname = "swamp";
  inherit (source) version src;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontStrip = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 swamp $out/bin/swamp

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "git-tags";
        url = "https://git.swamp-club.com/api/v1/repos/swamp-club/swamp/tags?limit=50";
      };
    }
  );

  meta = with lib; {
    description = "Deterministic automation for AI agents";
    homepage = "https://swamp-club.com/";
    changelog = "https://git.swamp-club.com/swamp-club/swamp/src/tag/v${source.version}";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ selmison ];
    platforms = source.platforms;
    mainProgram = "swamp";
  };
}
