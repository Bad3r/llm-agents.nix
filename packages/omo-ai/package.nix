{
  lib,
  flake,
  buildNpmPackage,
  fetchurl,
  runCommand,
  nodejs,
  fd,
  ripgrep,
  claude-code,
  mkUpdater,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;

  # The npm tarball ships no lockfile, so vendor the one the updater refreshes
  # on every bump.
  srcWithLock = runCommand "omo-ai-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/omo-ai/-/omo-ai-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "omo-ai";
  inherit version;

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;

  # The tarball ships prebuilt dist/ and the senpi engine; install scripts
  # stay enabled so the postinstall (bin/senpi-patch.mjs) floors the
  # claudeCodeVersion and stamps the engine tree.
  dontNpmBuild = true;
  makeCacheWritable = true;

  postInstall = ''
    wrapProgram "$out/bin/omo" \
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
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  # --version never loads the engine bundle, so smoke-test a real launch too.
  postInstallCheck = ''
    output=$(HOME=$TMPDIR $out/bin/omo --help 2>&1 || true)
    grep -q "Usage:" <<<"$output"
  '';

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/omo-ai";
  };

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
