{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  stdenv,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # build.rs embeds a LiteLLM pricing snapshot. Without a local file it
  # downloads model_prices_and_context_window.json at build time, which the
  # sandbox forbids, so pass a pinned copy via CCUSAGE_PRICING_JSON_PATH.
  # build.rs resolves that URL from nodes.litellm.locked in the tagged tree's
  # flake.lock, so the pin must match it exactly or we embed different prices
  # than upstream ships. update.py re-reads it from the tag on every bump.
  litellmRev = "dc0237ccd722c7e4d010b9a29ff4ba22af217f5b";
  litellm-pricing = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/${litellmRev}/model_prices_and_context_window.json";
    hash = "sha256-lvDiIIARNXiscr0Pe/mv5LytGfBNx9fdyIkGKJHFGg8=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "ccusage";
  version = "20.0.43";

  src = fetchFromGitHub {
    owner = "ccusage";
    repo = "ccusage";
    tag = "v${version}";
    hash = "sha256-r+bFun3sUUjyHmnj2YTidjBQznS0ggsCXzhb72VBjLM=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-5a/XDiAudVVqrrlpfxfMYnih+J8fNl4dnjH6rw+zKps=";

  cargoBuildFlags = [
    "-p"
    "ccusage"
    "--bin"
    "ccusage"
  ];

  # Workspace tests need fixture crates and insta snapshots that the tagged
  # tarball builds cannot satisfy; upstream's own derivation skips them too.
  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  # nixpkgs' Darwin cc-wrapper injects -liconv even though ccusage references no
  # iconv symbols, leaving an unused store dependency (upstream ccusage#1251).
  # dead_strip_dylibs drops load commands whose symbols are never referenced.
  env.RUSTFLAGS = lib.optionalString stdenv.hostPlatform.isDarwin "-C link-arg=-Wl,-dead_strip_dylibs";

  env.CCUSAGE_PRICING_JSON_PATH = litellm-pricing;

  # build.rs falls back to the tagged tree's own version, but the tag is
  # authoritative for what we claim to ship.
  env.CCUSAGE_VERSION = version;

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://ccusage.com/";
    changelog = "https://github.com/ccusage/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.unix;
  };
}
