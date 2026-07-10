{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  stdenv,
  libiconv,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # build.rs embeds a LiteLLM pricing snapshot. Without a local file it
  # downloads model_prices_and_context_window.json at build time, which the
  # sandbox forbids. Pin the same litellm rev as upstream's flake.lock
  # (nodes.litellm.locked) and pass it via CCUSAGE_PRICING_JSON_PATH.
  litellm-pricing = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/e59e34bed3670a6894d43129c2af16af28057d03/model_prices_and_context_window.json";
    hash = "sha256-aPue4NpPpTKAtAYCI8S8ojmVCDtYr+mxwtYkOASEg3w=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "ccusage";
  version = "20.0.16";

  src = fetchFromGitHub {
    owner = "ryoppippi";
    repo = "ccusage";
    tag = "v${version}";
    hash = "sha256-JwWMAMBA9Ya3Er2t8NunR4NKDXCwlZl2Y9r30kzDT9M=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-FT4XyYyG3P6sp7w0GcG2b2I4oXafhoFdgF8mmypLwbQ=";

  cargoBuildFlags = [
    "-p"
    "ccusage"
    "--bin"
    "ccusage"
  ];

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

  env.CCUSAGE_PRICING_JSON_PATH = litellm-pricing;

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.all;
  };
}
