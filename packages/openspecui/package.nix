{
  buildNpmPackage,
  fetchurl,
  flake,
  jq,
  lib,
  mkUpdater,
  runCommand,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with the vendored package-lock.json included
  # Strip devDependencies which contain workspace:* references that npm cannot resolve
  srcWithLock = runCommand "openspecui-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/openspecui/-/openspecui-${version}.tgz";
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
  inherit version;
  pname = "openspecui";

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  makeCacheWritable = true;

  # onnxruntime-node's postinstall tries to download native binaries from
  # nuget.org, which fails in the nix sandbox. Skip all install scripts
  # during npm rebuild, then selectively rebuild native addons that need it.
  npmRebuildFlags = [ "--ignore-scripts" ];
  preBuild = ''
    npm rebuild better-sqlite3 sharp @parcel/watcher esbuild protobufjs
  '';

  dontNpmBuild = true;

  passthru.category = "Workflow & Project Management";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/openspecui";
    stripDevDependencies = true;
  };

  meta = {
    description = "Visual interface for spec-driven development";
    homepage = "https://github.com/jixoai/openspecui";
    changelog = "https://github.com/jixoai/openspecui/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/openspecui";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "openspecui";
  };
}
