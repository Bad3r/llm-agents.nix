{
  lib,
  stdenv,
  fetchurl,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-amd64";
    "aarch64-darwin" = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");

in
stdenv.mkDerivation {
  pname = "open-code-review";
  inherit version;

  src = fetchurl {
    url = "https://github.com/alibaba/open-code-review/releases/download/v${version}/opencodereview-${platformSuffix}";
    hash = hashes.${platform};
  };

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
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
