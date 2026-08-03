{
  flake,
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  rustPlatform,
  nodejs_22,
  openssl,
  pkg-config,
  pnpm_11,
  pnpmConfigHook,
  writeShellScriptBin,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # frontend/package.json pins node 22 and pnpm 11 via `engines`.
  pnpm = pnpm_11.override { nodejs-slim = nodejs_22; };
  # The webui build.rs runs `corepack pnpm ...`.
  # Forward that to our pnpm instead of letting corepack download its own.
  corepack = writeShellScriptBin "corepack" ''
    shift
    exec ${pnpm}/bin/pnpm "$@"
  '';
in
rustPlatform.buildRustPackage rec {
  pname = "ironclaw";
  version = "1.0.0-rc.1";

  src = fetchFromGitHub {
    owner = "nearai";
    repo = "ironclaw";
    tag = "ironclaw-v${version}";
    hash = "sha256-1Err4VlwZgRL3Wyn3lFw2diSKa+Jr+GQXk7OpCYFu8M=";
  };

  cargoHash = "sha256-wnnkl0DZTXhanUtul0EmW8+jp/ZTRmfd/1LCXF137dU=";

  pnpmDeps = fetchPnpmDeps {
    pname = "${pname}-webui";
    inherit version src;
    inherit pnpm;
    sourceRoot = "source/crates/ironclaw_webui/frontend";
    hash = "sha256-+dEMbruwOengINcmRTBq4Xb3tgQmEQmnqEghl6EDnAU=";
    fetcherVersion = 4;
  };
  pnpmRoot = "crates/ironclaw_webui/frontend";

  nativeBuildInputs = [
    corepack
    nodejs_22
    pkg-config
    pnpm
    pnpmConfigHook
  ];
  buildInputs = [ openssl ];

  # cargo-auditable's metadata collection cannot resolve the upstream
  # workspace's private libsql feature aliases.
  auditable = false;

  cargoBuildFlags = [
    "--package"
    "ironclaw"
  ];

  # Upstream's smoke tests require host CA certificates and GNU awk, but do
  # not arrange either in Cargo's test environment.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Assistants";

  meta = {
    description = "Secure personal AI assistant that protects your data and expands its capabilities on the fly";
    homepage = "https://github.com/nearai/ironclaw";
    changelog = "https://github.com/nearai/ironclaw/releases/tag/ironclaw-v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ kmjayadeep ];
    mainProgram = "ironclaw";
    platforms = lib.platforms.all;
  };
}
