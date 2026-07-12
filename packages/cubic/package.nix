{
  lib,
  flake,
  stdenv,
  fetchurl,
  unzip,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "cubic";
  inherit version;

  src = fetchurl {
    url = "https://mcafvrhahbqdwfrtncql.supabase.co/storage/v1/object/public/releases/v${version}/cubic-${platformSuffix}.zip";
    hash = hashes.${platform};
  };

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  unpackPhase = ''
    unzip $src
  '';

  dontStrip = true; # bun runtime embeds JS at the tail of the binary

  installPhase = ''
    runHook preInstall

    install -Dm755 cubic $out/bin/cubic

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "Code Review";

  meta = with lib; {
    description = "AI code review CLI from cubic.dev - fast pre-flight review before you push";
    homepage = "https://cubic.dev";
    changelog = "https://docs.cubic.dev/ide/cli-review";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ryoppippi ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "cubic";
  };
}
