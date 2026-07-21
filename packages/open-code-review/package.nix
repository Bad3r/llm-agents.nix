{
  lib,
  stdenv,
  platformSource,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    url =
      { version, platform }:
      "https://github.com/alibaba/open-code-review/releases/download/v${version}/opencodereview-${platform}";
  };
  inherit (source) version;
in
stdenv.mkDerivation {
  pname = "open-code-review";
  inherit (source) version src;

  # Upstream releases are single statically linked Go binaries.
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 $src $out/bin/ocr
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "version" ];

  passthru.category = "Code Review";

  meta = with lib; {
    description = "AI-powered code review CLI";
    homepage = "https://github.com/alibaba/open-code-review";
    changelog = "https://github.com/alibaba/open-code-review/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "ocr";
    maintainers = with maintainers; [ fridh ];
    platforms = source.platforms;
  };
}
