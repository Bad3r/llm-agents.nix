{
  lib,
  buildNpmPackage,
  fetchurl,
  flake,
  nodejs_22,
  runCommand,
  makeWrapper,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;

  # The npm tarball ships no lockfile. Vendor one, kept in sync by update.py.
  srcWithLock = runCommand "dsh-source" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "dsh";
  inherit version;
  src = srcWithLock;

  nodejs = nodejs_22;
  npmDepsFetcherVersion = 2;
  npmDepsHash = versionData.npmDepsHash;

  # The npm package already contains the compiled CLI files.
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    mkdir -p $out/lib/dsh $out/bin
    cp -r lib config package.json README* node_modules $out/lib/dsh/

    makeWrapper ${lib.getExe nodejs_22} $out/bin/dsh \
      --add-flags "$out/lib/dsh/lib/bin.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Open-source agent harness developed by DeepSeek AI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ JachinShen ];
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
}
