{
  lib,
  buildNpmPackage,
  fetchurl,
  flake,
  mkUpdater,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  srcWithLock = runCommand "minimax-code-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@minimax-ai/code/-/code-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "minimax-code";
  inherit version;
  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  npmDepsFetcherVersion = 2;

  # root postinstall and @vscode/ripgrep hit the network
  npmFlags = [ "--ignore-scripts" ];
  preBuild = "npm rebuild --ignore-scripts=false better-sqlite3";
  dontNpmBuild = true;

  postInstall = ''
    find $out -path '*/better-sqlite3/build/*' ! -name better_sqlite3.node -type f -delete
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/%40minimax-ai/code";
  };

  meta = {
    description = "Open-source coding agent for your terminal, powered by MiniMax";
    homepage = "https://github.com/MiniMax-AI/minimax-code";
    changelog = "https://www.npmjs.com/package/@minimax-ai/code/v/${version}";
    downloadPage = "https://www.npmjs.com/package/@minimax-ai/code?activeTab=versions";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ _74k1 ];
    mainProgram = "mcode";
    platforms = lib.platforms.unix;
  };
}
