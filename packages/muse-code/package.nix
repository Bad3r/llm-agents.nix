{
  lib,
  stdenvNoCC,
  flake,
  fetchurlTemplate,
  versionCheckHook,
  mkUpdater,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version;

  platforms = {
    x86_64-linux = "x86-linux";
    aarch64-linux = "aarch64-linux";
    aarch64-darwin = "aarch64-macos";
  };

  system = stdenvNoCC.hostPlatform.system;
  platform = platforms.${system} or (throw "Unsupported system: ${system}");

  downloadBase = "https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version={version}";
in
stdenvNoCC.mkDerivation {
  pname = "muse-code";
  inherit version;

  src = fetchurlTemplate {
    urlTemplate = "${downloadBase}&file=muse-{platform}";
    vars = {
      inherit version platform;
    };
    name = "muse-${version}-${platform}";
    hash = versionData.hashes.${system};
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/muse
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater {
    kind = "manifest-checksums";
    versionSource = {
      type = "text";
      url = "https://api.meta.ai/muse-code/channels/muse-stable";
      regex = ''"version": *"([^"]+)"'';
    };
    manifestUrl = "${downloadBase}&file=manifest.json";
    checksumPath = "artifacts.{platform}.checksum";
    # Manifest keys use x86_linux instead of x86-linux.
    platforms = lib.mapAttrs (_: lib.replaceStrings [ "-" ] [ "_" ]) platforms;
  };

  meta = {
    description = "Meta's terminal coding agent";
    homepage = "https://dev.meta.ai/";
    changelog = "https://dev.meta.ai/docs/muse-code/changelog";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ willenbug ];
    mainProgram = "muse";
    platforms = builtins.attrNames platforms;
  };
}
