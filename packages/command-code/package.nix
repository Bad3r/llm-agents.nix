{
  lib,
  buildNpmPackage,
  fetchurl,
  flake,
  jq,
  mkUpdater,
  nodejs_22,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # The npm tarball ships no lockfile, so vendor one alongside the source. The
  # lockfile is generated without devDependencies (see the updater config), so
  # the manifest has to lose them too or npm re-resolves the whole tree.
  srcWithLock = runCommand "command-code-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/command-code/-/command-code-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "command-code";
  inherit version;
  nodejs = nodejs_22;

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;

  # The install scripts fetch from the network. Nothing needs them: @vscode/
  # ripgrep only downloads a binary its platform package already ships, and
  # @vscode/ripgrep resolves rgPath into that package.
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  NPM_CONFIG_IGNORE_SCRIPTS = "true";

  # dist/ is a prebuilt tsup bundle; the build script needs a checkout the
  # tarball does not carry (../../scripts/build-ext.sh).
  dontNpmBuild = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/command-code";
    # The platform-gated @lydell/node-pty-* devDependencies make `npm install
    # --package-lock-only` abort with "Cannot read properties of null"; nothing
    # in dist/ needs them.
    stripDevDependencies = true;
  };

  meta = {
    description = "Coding agent that learns your coding taste, for open models";
    homepage = "https://commandcode.ai";
    downloadPage = "https://www.npmjs.com/package/command-code?activeTab=versions";
    # Upstream publishes no public repository or release notes; the changelog
    # ships inside the npm tarball.
    changelog = "https://www.npmjs.com/package/command-code/v/${version}";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ zimbatm ];
    mainProgram = "cmd";
    platforms = lib.platforms.all;
  };
}
