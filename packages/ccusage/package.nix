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
  version = "20.0.8";

  src = fetchFromGitHub {
    owner = "ryoppippi";
    repo = "ccusage";
    rev = "v${version}";
    hash = "sha256-jlQoavZ/dvqA3gFoXzp4vY9SmLdp7RrVSbKodnAk878=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-SdsrT0DT3j7RghQ8GhXUf+ahQKxc+B4+C8ZY3dYg+i8=";

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
