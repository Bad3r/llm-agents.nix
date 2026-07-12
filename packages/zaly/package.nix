{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with package-lock.json included (npm tarball ships without one)
  srcWithLock = runCommand "zaly-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@zaly/cli/-/cli-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "zaly";
  inherit version;

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;

  # Skip dependency install scripts; sharp ships prebuilt binaries and the
  # root postinstall only rewrites the already-correct node shebang.
  npmRebuildFlags = [ "--ignore-scripts" ];

  # The npm tarball ships a prebuilt dist/
  dontNpmBuild = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Hackable terminal coding agent";
    homepage = "https://github.com/folke/zaly";
    downloadPage = "https://www.npmjs.com/package/@zaly/cli";
    changelog = "https://github.com/folke/zaly/releases/tag/cli-v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ sei40kr ];
    mainProgram = "zaly";
    platforms = platforms.all;
  };
}
