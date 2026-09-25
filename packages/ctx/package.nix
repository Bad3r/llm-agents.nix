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
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rzQBRaFX4wL0v9CbSOEiupG0LET1zoECCun7QV9wu0w=";
  };

  cargoHash = "sha256-W6PyLvx/o+8RzTFELwIe5+/4hk/KSbHYQrwslKCq1qE=";

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
