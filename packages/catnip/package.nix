{
  lib,
  stdenv,
  platformSource,
  wrapBuddy,
  gcc-unwrapped,
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
      "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_${platform}.tar.gz";
  };
in
stdenv.mkDerivation {
  pname = "catnip";
  inherit (source) version src;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          mkdir -p $out/Applications
          cp -r Catnip.app $out/Applications/
          mkdir -p $out/bin
          ln -s $out/Applications/Catnip.app/Contents/MacOS/catnip $out/bin/catnip
        ''
      else
        ''
          install -Dm755 catnip $out/bin/catnip
        ''
    }

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "Developer environment that's like catnip for agentic programming";
    homepage = "https://github.com/wandb/catnip";
    changelog = "https://github.com/wandb/catnip/releases/tag/v${source.version}";
    downloadPage = "https://github.com/wandb/catnip/releases";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = source.platforms;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "catnip";
  };
}
