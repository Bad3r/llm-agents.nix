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
  version = "0.8.5";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-X+2hSmbGibS0LJDew+CnXpJFW2k7w3fj/D54XHqLLzI=";
  };

  # fetchNpmDeps needs package-lock.json at the source root.
  frontendSrc = runCommand "${pname}-web-src-${version}" { } ''
    mkdir -p $out
    cp -r ${src}/web/. $out/
  '';
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = "sha256-a0tr5K6KReLRRN4X8sjJrriHy/n0LC7amlOHtM765eg=";

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  env.NIX_NPM_FETCHER_VERSION = "2";

  # `cargo run` in preBuild bypasses cargoBuildHook's linker env vars.
  env."CARGO_TARGET_${stdenv.hostPlatform.rust.cargoEnvVarTarget}_LINKER" =
    "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc";

  npmDeps = fetchNpmDeps {
    # nix-update needs a version attribute to update the subpackage hash
    inherit version;
    src = frontendSrc;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-TEHovW+hdq9kiYj3T+h0QLvMsLG7LYszzpmZ+o7txvk=";
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
