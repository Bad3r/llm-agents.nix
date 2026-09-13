{
  lib,
  flake,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
  fd,
  ripgrep,
  claude-code,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version senpiVersion;

  # senpi (a pi fork) publishes with its entire dependency tree bundled, so
  # the only other thing omo needs is senpi itself.
  senpi = fetchurl {
    url = "https://registry.npmjs.org/@code-yeongyu/senpi/-/senpi-${senpiVersion}.tgz";
    hash = versionData.senpiHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "omo-ai";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/omo-ai/-/omo-ai-${version}.tgz";
    inherit (versionData) hash;
  };
  sourceRoot = "package";

  nativeBuildInputs = [
    makeWrapper
    nodejs
  ];

  buildPhase = ''
    runHook preBuild
    mkdir -p node_modules/@code-yeongyu/senpi
    tar -xzf ${senpi} --strip-components=1 -C node_modules/@code-yeongyu/senpi
    test "$(node -p 'require("./package.json").dependencies["@code-yeongyu/senpi"]')" = ${senpiVersion}
    node bin/senpi-patch.mjs
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r . $out/lib/omo-ai
    makeWrapper ${lib.getExe nodejs} $out/bin/omo \
      --add-flags $out/lib/omo-ai/bin/omo.js \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          fd
          ripgrep
        ]
      } \
      --set-default CLAUDE_CODE_EXECUTABLE ${lib.getExe claude-code} \
      --set-default OMO_TELEMETRY 0 \
      --set-default OMO_SEND_ANONYMOUS_TELEMETRY 0
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Oh My OpenAgent standalone (Senpi edition) coding agent";
    homepage = "https://github.com/code-yeongyu/oh-my-openagent";
    changelog = "https://github.com/code-yeongyu/oh-my-openagent/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ ankarhem ];
    inherit (nodejs.meta) platforms;
    mainProgram = "omo";
  };
}
