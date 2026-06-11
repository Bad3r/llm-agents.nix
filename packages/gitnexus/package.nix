{
  flake,
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  forceGitDeps = true;
  pname = "gitnexus";
  version = "1.6.6";

  src = fetchFromGitHub {
    owner = "abhigyanpatwari";
    repo = "GitNexus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6j6phmZwbfXMcHFbDNjOD78lBF67c3a+a5x6qo7p4as=";
  };

  sourceRoot = "source/gitnexus";

  patches = [ ./system-onnxruntime-node.patch ];

  postUnpack = ''
    chmod -R u+w source/gitnexus-shared
    # build.js runs `npm ci && npm run build` inside gitnexus-web (needs
    # network and a separate lockfile). Drop its package.json so the
    # build script skips the web UI entirely.
    chmod -R u+w source/gitnexus-web
    rm -f source/gitnexus-web/package.json
  '';

  # build.js invokes a cwd-relative node_modules/.bin/tsc which does not exist
  # in gitnexus-shared; use the tsc from nativeBuildInputs on PATH instead.
  postPatch = ''
    substituteInPlace scripts/build.js \
      --replace-fail "path.join('node_modules', '.bin', 'tsc')" "'tsc'"
  '';

  npmDepsHash = "sha256-EG4/uRujXRVbjJkU6Q+YKOKPejIWIeSmjD/dYatuGZM=";
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  # --ignore-scripts skips the upstream postinstall that copies vendored
  # tree-sitter grammars (dart/proto/swift) into node_modules; tsc needs
  # their type declarations. The native binding build is still skipped, as
  # it was with the 1.6.5 file: optionalDependencies under --ignore-scripts.
  preBuild = ''
    node scripts/materialize-vendor-grammars.cjs
  '';

  nativeBuildInputs = [
    makeWrapper
    typescript
  ];

  dontPatchELF = stdenv.hostPlatform.isDarwin;

  postInstall =
    let
      ortPlatform =
        if stdenv.hostPlatform.isDarwin then
          "darwin"
        else if stdenv.hostPlatform.isLinux then
          "linux"
        else
          throw "Unsupported platform for gitnexus: ${stdenv.hostPlatform.system}";
      ortArch =
        if stdenv.hostPlatform.isAarch64 then
          "arm64"
        else if stdenv.hostPlatform.isx86_64 then
          "x64"
        else
          throw "Unsupported CPU for gitnexus: ${stdenv.hostPlatform.parsed.cpu.name}";
      ortBinding = "$out/lib/node_modules/gitnexus/node_modules/onnxruntime-node/bin/napi-v6/${ortPlatform}/${ortArch}/onnxruntime_binding.node";
      lbugBindingSource = "$out/lib/node_modules/gitnexus/node_modules/@ladybugdb/core-${ortPlatform}-${ortArch}/lbugjs.node";
      lbugBindingTarget = "$out/lib/node_modules/gitnexus/node_modules/@ladybugdb/core/lbugjs.node";
    in
    ''
      if [ -f "${lbugBindingSource}" ]; then
        cp "${lbugBindingSource}" "${lbugBindingTarget}"
      else
        echo "Expected LadybugDB native module at ${lbugBindingSource} but it was not found." >&2
        exit 1
      fi

      wrapProgram $out/bin/gitnexus \
        --set-default GITNEXUS_ORT_BINDING_PATH "${ortBinding}"
    '';

  passthru.category = "Memory & Code Intelligence";

  meta = with lib; {
    description = "Graph-powered code intelligence for AI agents";
    homepage = "https://github.com/abhigyanpatwari/GitNexus";
    changelog = "https://github.com/abhigyanpatwari/GitNexus/releases";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ PieterPel ];
    mainProgram = "gitnexus";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
