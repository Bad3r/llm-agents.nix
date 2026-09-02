{
  lib,
  flake,
  mkUpdater,
  stdenv,
  platformSource,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # The per-platform builds are dist-tagged versions of `executor` itself, so
  # the platform token is part of the version rather than the package name.
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://registry.npmjs.org/executor/-/executor-{version}-{platform}.tgz";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "executor";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontBuild = true;

  # bun --compile binary: its payload trailer must stay at EOF, so nothing may
  # strip or resize it. wrapBuddy patches the entry point in place; patchelf and
  # autoPatchelfHook both grow the file and the CLI then silently degrades to
  # bun's own command line.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${finalAttrs.pname}
    cp -r . $out/lib/${finalAttrs.pname}

    # The .node addons are dlopen'd, so wrapBuddy leaves them alone and they
    # resolve through LD_LIBRARY_PATH.
    makeWrapper $out/lib/${finalAttrs.pname}/bin/executor $out/bin/executor \
      ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [ stdenv.cc.cc.lib ]
      }"''}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "Utilities";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "npm";
        package = "executor";
      };
    }
  );

  meta = {
    description = "MCP gateway that gives coding agents one interface to many tools";
    longDescription = ''
      Executor presents MCP servers, OpenAPI services and scripts to coding
      agents as one tool abstraction. It stores credentials, separates safe and
      unsafe API semantics, and runs tool calls in isolated JavaScript
      sandboxes. It ships a CLI, a local API server and a web UI.
    '';
    homepage = "https://executor.sh";
    changelog = "https://github.com/UsefulSoftwareCo/executor/releases";
    downloadPage = "https://www.npmjs.com/package/executor?activeTab=versions";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ zimbatm ];
    mainProgram = "executor";
    platforms = source.platforms;
  };
})
