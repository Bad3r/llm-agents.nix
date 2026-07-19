{
  lib,
  flake,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  runCommand,
  nodejs,
  fetchNpmDeps,
  npmHooks,
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

  # fetchNpmDeps needs package-lock.json at the source root.
  frontendSrc = runCommand "${pname}-web-src-${version}" { } ''
    mkdir -p $out
    cp -r ${src}/web/. $out/
  '';
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = "sha256-zLj2ItDp8tbldBvFNxlrcoqcE0J5Ce19NDlV+lCu/BY=";

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  env.NIX_NPM_FETCHER_VERSION = "2";

  # `cargo run` in preBuild bypasses cargoBuildHook's linker env vars.
  env."CARGO_TARGET_${stdenv.hostPlatform.rust.cargoEnvVarTarget}_LINKER" =
    "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc";

  npmDeps = fetchNpmDeps {
    src = frontendSrc;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-5lj/KyxZ87LYLR8jHbIiAohpXrqrQNwqLdenDgCmk5k=";
    fetcherVersion = 2;
  };
  npmRoot = "web";
  makeCacheWritable = true;

  # gen-api renders the gateway's OpenAPI spec and generates the TS API
  # modules the frontend imports; the gateway embeds web/dist via include_dir!.
  preBuild = ''
    cargo run --offline -p xtask --bin web -- gen-api
    npm --prefix web run build
  '';

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru = {
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
