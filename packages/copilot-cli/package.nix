{
  lib,
  flake,
  mkUpdater,
  stdenv,
  platformSource,
  makeWrapper,
  formatelf,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # Since 1.0.64 the @github/copilot npm package is just a loader that resolves
  # and spawns a per-platform package (@github/copilot-<platform>-<arch>), which
  # ships the actual Node SEA binary plus bundled ripgrep/tgrep.
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://registry.npmjs.org/@github/copilot-{platform}/-/copilot-{platform}-{version}.tgz";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "copilot-cli";
  inherit (source) version src;

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ formatelf ];

  dontBuild = true;

  # `copilot` is a Node single-executable application with an embedded blob.
  dontStrip = true;
  dontPatchELF = true;

  installPhase =
    let
      libPath = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
    in
    ''
      runHook preInstall

      mkdir -p $out/lib/${finalAttrs.pname}
      cp -r . $out/lib/${finalAttrs.pname}
      bin=$out/lib/${finalAttrs.pname}/copilot

      # Native addons are extracted to ~/.cache at runtime, out of the hook's reach.
      makeWrapper "$bin" $out/bin/copilot \
        --set-default COPILOT_AUTO_UPDATE false \
        ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix LD_LIBRARY_PATH : "${libPath}"''}

      runHook postInstall
    '';

  doInstallCheck = true;
  # The Node SEA self-extracts its bundled package into $HOME on first run, so
  # the version check needs a writable HOME.
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "npm";
        package = "@github/copilot";
      };
    }
  );

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal.";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${finalAttrs.version}";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = source.platforms;
    mainProgram = "copilot";
  };
})
