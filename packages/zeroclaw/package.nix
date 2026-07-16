{
  lib,
  flake,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  runCommand,
  nodejs,
  fetchNpmDeps,
  npmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:
let
  pname = "zeroclaw";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-H1512vayE35bLxlFpWExT6u/z3rMKsrv6gs5un9IPaA=";
  };

  frontendSrc = runCommand "${pname}-web-src-${version}" { } ''
    mkdir -p $out
    cp -r ${src}/web/. $out/
  '';

  frontend = stdenv.mkDerivation {
    pname = "${pname}-frontend";
    inherit version;
    src = frontendSrc;

    nativeBuildInputs = [
      nodejs
      npmConfigHook
    ];

    env.NIX_NPM_FETCHER_VERSION = "2";

    npmDeps = fetchNpmDeps {
      src = frontendSrc;
      name = "${pname}-${version}-npm-deps";
      hash = "sha256-5lj/KyxZ87LYLR8jHbIiAohpXrqrQNwqLdenDgCmk5k=";
      fetcherVersion = 2;
    };
    makeCacheWritable = true;

    # `api-generated.ts` is normally produced by `cargo web gen-api`, which
    # renders the gateway's OpenAPI spec and pipes it through openapi-typescript.
    # It is only re-exported as a type from api.ts and never consumed elsewhere,
    # so stub it instead of pulling the whole Rust toolchain into the frontend.
    # The stubs use `any` because api.ts indexes nested members (e.g.
    # components["schemas"]["ConfigApiCode"]); a `Record<string, unknown>` stub
    # makes the inner access fail with TS2339.
    postPatch = ''
      cat > src/lib/api-generated.ts <<'EOF'
      /* eslint-disable @typescript-eslint/no-explicit-any */
      export type paths = any;
      export type components = any;
      EOF
    '';

    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage rec {
  inherit pname version src;

  cargoHash = "sha256-zLj2ItDp8tbldBvFNxlrcoqcE0J5Ce19NDlV+lCu/BY=";

  preBuild = ''
    mkdir -p web/dist
    cp -r ${frontend}/* web/dist/
  '';

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru = {
    inherit frontend;
    category = "AI Assistants";
  };

  meta = {
    description = "Fast, small, and fully autonomous AI assistant infrastructure";
    homepage = "https://github.com/zeroclaw-labs/zeroclaw";
    changelog = "https://github.com/zeroclaw-labs/zeroclaw/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "zeroclaw";
    platforms = lib.platforms.unix;
  };
}
