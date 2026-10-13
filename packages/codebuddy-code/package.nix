{
  lib,
  flake,
  buildNpmPackage,
  fetchurl,
  mkUpdater,
  nodejs,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  srcWithLock = runCommand "codebuddy-code-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@tencent-ai/codebuddy-code/-/codebuddy-code-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "codebuddy-code";
  inherit version;
  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  npmDepsFetcherVersion = 2;

  # The published tarball is already bundled; skip install scripts.
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  makeWrapperArgs = [ "--set DISABLE_AUTOUPDATER 1" ];

  # The generated wrapper runs `node <script>`, which skips the node flags in
  # the script's shebang.
  postInstall = ''
    rm $out/bin/codebuddy-lowmem
    makeWrapper ${lib.getExe nodejs} $out/bin/codebuddy-lowmem $makeWrapperArgs \
      --add-flags "--optimize-for-size --max-semi-space-size=2" \
      --add-flags $out/lib/node_modules/@tencent-ai/codebuddy-code/bin/codebuddy-lowmem
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/%40tencent-ai/codebuddy-code";
  };

  meta = {
    description = "Tencent's AI coding agent for the terminal";
    homepage = "https://www.codebuddy.ai/cli";
    changelog = "https://www.npmjs.com/package/@tencent-ai/codebuddy-code/v/${version}";
    downloadPage = "https://www.npmjs.com/package/@tencent-ai/codebuddy-code?activeTab=versions";
    # package.json points to the README, the licence is in LICENSE.txt.
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    maintainers = with flake.lib.maintainers; [ YuXiangggg ];
    mainProgram = "codebuddy";
    platforms = lib.platforms.unix;
  };
}
