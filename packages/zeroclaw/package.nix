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
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-dB/M5QdAyql/WXxwkX9V/bkiRsAv0J+tIbQN0wKLJpM=";
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
      hash = "sha256-NbeGCnSUGKzHU4c7ErCqITUsAMT7FWSf08YWKvKrAE8=";
      fetcherVersion = 2;
    };
    makeCacheWritable = true;

    # `api-generated.ts` is normally produced by `cargo web gen-api`, which
    # renders the gateway's OpenAPI spec and pipes it through openapi-typescript.
    # It is only re-exported as a type from api.ts and never consumed elsewhere,
    # so stub it instead of pulling the whole Rust toolchain into the frontend.
    postPatch = ''
      cat > src/lib/api-generated.ts <<'EOF'
      export type paths = Record<string, unknown>;
      export type components = Record<string, unknown>;
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

  cargoHash = "sha256-ZBmz877jEkTGopa5QxNUguxxKO45aZ6K5GXXAv4Ii4s=";

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
