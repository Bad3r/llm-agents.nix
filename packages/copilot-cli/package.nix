{
  lib,
  flake,
  stdenv,
  platformSource,
  makeWrapper,
  patchelf,
  cacert,
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
      x86_64-darwin = "darwin-x64";
      aarch64-darwin = "darwin-arm64";
    };
    url =
      { version, platform }:
      "https://registry.npmjs.org/@github/copilot-${platform}/-/copilot-${platform}-${version}.tgz";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "copilot-cli";
  inherit (source) version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ patchelf ];

  dontBuild = true;

  # `copilot` is a Node single-executable application with an embedded blob;
  # stripping or rewriting its program headers corrupts it.
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
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # `copilot` is a Node single-executable application; autoPatchelfHook
      # grows the program headers and corrupts the embedded SEA blob, so patch
      # the interpreter and rpath minimally instead. The bundled .node libraries
      # are dlopen'd, so make their dependencies available via LD_LIBRARY_PATH;
      # the bundled rg/tgrep are static-pie and need nothing.
      patchelf \
        --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
        --set-rpath "${libPath}" \
        "$bin"
    ''
    + ''
      makeWrapper "$bin" $out/bin/copilot \
        --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
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
