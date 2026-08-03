{
  lib,
  flake,
  stdenv,
  fetchurl,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
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

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  pname = "swamp";
  inherit version;

  src = fetchurl {
    url = "https://artifacts.swamp-club.com/swamp/${version}/binary/${platform.os}/${platform.cpu}/swamp-${version}-binary-${platform.os}-${platform.cpu}.tar.gz";
    hash = hashes.${system};
  };

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

  meta = with lib; {
    description = "Deterministic automation for AI agents";
    homepage = "https://swamp-club.com/";
    changelog = "https://git.swamp-club.com/swamp-club/swamp/src/tag/v${version}";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ selmison ];
    platforms = builtins.attrNames platformMap;
    mainProgram = "swamp";
  };
}
