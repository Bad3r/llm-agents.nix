{
  lib,
  flake,
  stdenv,
  fetchurl,
  platformSource,
  cacert,
  makeWrapper,
  nodejs,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    url =
      { version, platform }:
      "https://registry.npmjs.org/@cline/cli-${platform}/-/cli-${platform}-${version}.tgz";
  };
  launcher = fetchurl {
    url = "https://registry.npmjs.org/cline/-/cline-${source.version}.tgz";
    hash = versionData.launcherHash;
  };
in
stdenv.mkDerivation {
  pname = "cline";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = [
    makeWrapper
    nodejs
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/cline-platform $out/lib/cline-launcher
    cp -r . $out/lib/cline-platform
    tar -xzf ${launcher} --strip-components=1 -C $out/lib/cline-launcher package/bin

    # Use the official npm launcher so Cline retains its OS trust-store
    # handling. The npm postinstall normally caches this platform binary as
    # bin/.cline; a symlink provides the same immutable Nix-store layout.
    ln -s $out/lib/cline-platform/bin/cline $out/lib/cline-launcher/bin/.cline
    patchShebangs $out/lib/cline-launcher/bin/cline

    makeWrapper $out/lib/cline-launcher/bin/cline $out/bin/cline \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --set-default SSL_CERT_DIR ${cacert}/etc/ssl/certs

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Autonomous coding agent CLI";
    homepage = "https://cline.bot";
    changelog = "https://github.com/cline/cline/releases/tag/cli-v${source.version}";
    downloadPage = "https://www.npmjs.com/package/cline";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ poelzi ];
    mainProgram = "cline";
    platforms = source.platforms;
  };
}
