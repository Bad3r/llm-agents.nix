{
  lib,
  flake,
  buildNpmPackage,
  hindsight,
  inter,
  jetbrains-mono,
  jq,
  makeWrapper,
  nodejs,
}:
buildNpmPackage {
  pname = "hindsight-control-plane";
  inherit (hindsight) version src;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-Rr4Ux7mRo0zkcnMwN3DdSg967sYhZSsy7tKwSpqZC1A=";

  nativeBuildInputs = [ makeWrapper ];

  # next/font/google downloads the fonts at build time.
  patches = [ ./local-fonts.patch ];

  postPatch = ''
    # npm omitted these for two nested packages, so they cannot be prefetched.
    # By path, since this also runs in the npmDeps fetcher.
    ${lib.getExe jq} '
      .packages["hindsight-control-plane/node_modules/@types/node"] += {
        resolved: "https://registry.npmjs.org/@types/node/-/node-24.10.1.tgz",
        integrity: "sha512-GNWcUTRBgIRJD5zj+Tq0fKOJ5XZajIiBroOF0yvj2bSU1WvNdYS/dn9UxwsujGW4JX06dnHyjV2y9rRaybH0iQ=="
      }
      | .packages["hindsight-docs/node_modules/typescript"] += {
        resolved: "https://registry.npmjs.org/typescript/-/typescript-5.6.3.tgz",
        integrity: "sha512-hjcS1mhfuyi4WW8IWtjP7brDrG2cuDZukyrYrSauoXGNgx0S7zceP07adYkJycEr56BOUTNPzbInooiN3fn1qw=="
      }
    ' package-lock.json > package-lock.json.tmp
    mv package-lock.json.tmp package-lock.json

    fonts='hindsight-control-plane/src/app/[locale]/fonts'
    install -Dm644 ${inter}/share/fonts/truetype/InterVariable.ttf -t "$fonts"
    install -Dm644 '${jetbrains-mono}/share/fonts/truetype/JetBrainsMono[wght].ttf' \
      "$fonts/JetBrainsMono-Variable.ttf"

    substituteInPlace hindsight-control-plane/bin/cli.js \
      --replace-fail "spawn('node'," "spawn('${lib.getExe nodejs}',"
  '';

  # The root prepare script installs git hooks.
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmWorkspace = "hindsight-control-plane";

  env.NEXT_TELEMETRY_DISABLED = "1";

  # npmConfigHook only patches the root node_modules.
  preBuild = ''
    patchShebangs hindsight-*/node_modules hindsight-*/*/node_modules
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/hindsight-control-plane
    cp -r hindsight-control-plane/{bin,standalone} $out/lib/hindsight-control-plane/
    makeWrapper ${lib.getExe nodejs} $out/bin/hindsight-control-plane \
      --add-flags $out/lib/hindsight-control-plane/bin/cli.js

    runHook postInstall
  '';

  passthru.category = "AI Assistants";

  meta = {
    description = "Web UI for the Hindsight agent memory server";
    inherit (hindsight.meta)
      homepage
      changelog
      license
      sourceProvenance
      ;
    maintainers = with flake.lib.maintainers; [ wanderer ];
    mainProgram = "hindsight-control-plane";
    platforms = lib.platforms.unix;
  };
}
