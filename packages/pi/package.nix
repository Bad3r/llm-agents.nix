{
  lib,
  buildNpmPackage,
  bun,
  fetchurl,
  fd,
  ripgrep,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  packageRoot = "$out/lib/node_modules/@earendil-works/pi-coding-agent";

  # Create a source with package-lock.json included
  srcWithLock = runCommand "pi-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    rm -f $out/npm-shrinkwrap.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  inherit version;
  pname = "pi";

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  makeCacheWritable = true;

  # The package from npm is already built
  dontNpmBuild = true;

  nativeBuildInputs = [ bun ];

  # Compile a standalone binary like upstream's build:binary script. Running
  # dist/bun/cli.js directly with Bun breaks extension module aliasing (#6794).
  postInstall = ''
    pushd ${packageRoot}

    # Upstream embeds the worker as ./src/utils/image-resize-worker.ts and
    # loads it by that path at runtime; the npm tarball only ships dist/.
    mkdir -p src/utils
    echo 'import "../../dist/utils/image-resize-worker.js";' > src/utils/image-resize-worker.ts

    bun build --compile ./dist/bun/cli.js ./src/utils/image-resize-worker.ts --outfile pi-binary

    # Replicate upstream's copy-binary-assets layout next to the binary.
    pkgdir=$out/libexec/pi
    mkdir -p "$pkgdir/theme" "$pkgdir/assets" "$pkgdir/export-html/vendor"
    install -m755 pi-binary "$pkgdir/pi"
    cp package.json README.md CHANGELOG.md "$pkgdir/"
    cp -r docs examples "$pkgdir/"
    cp dist/modes/interactive/theme/*.json "$pkgdir/theme/"
    cp dist/modes/interactive/assets/*.png "$pkgdir/assets/"
    cp dist/core/export-html/template.html dist/core/export-html/template.css dist/core/export-html/template.js "$pkgdir/export-html/"
    cp dist/core/export-html/vendor/*.js "$pkgdir/export-html/vendor/"
    cp node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm "$pkgdir/"

    popd

    # The binary embeds all modules; drop the npm module tree.
    rm -rf "$out/lib" "$out/bin"
    mkdir -p "$out/bin"

    makeWrapper "$pkgdir/pi" "$out/bin/pi" \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$pkgdir" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/earendil-works/pi";
    changelog = "https://github.com/earendil-works/pi/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ aos ];
    platforms = bun.meta.platforms;
    mainProgram = "pi";
  };
}
