{
  lib,
  fetchFromGitHub,
  flake,
  rustPlatform,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ctx";
  version = "1.2.4";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-y3AOwzo5N1COlmw7AViu+pIUPO/oF8jxUlZh4mWDHvc=";
  };

  cargoHash = "sha256-pCIQL2u6C5Cg6BPx9oJ86BrA65HkX4ghMt2HJATBmFA=";

  cargoBuildFlags = [
    "--package"
    "ctx"
  ];

  # CoreML acquisition tests fail in Nix sandbox.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "Search the coding agent history already on your machine";
    homepage = "https://github.com/ctxrs/ctx";
    changelog = "https://github.com/ctxrs/ctx/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "ctx";
    platforms = lib.platforms.unix;
  };
})
