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
  version = "1.4.3";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Fw51pB1ZUpEkvpJ/a0i6Rx2k5dUeKurBTcPiVUxD+JY=";
  };

  cargoHash = "sha256-NaFAO3yoiemC7CXb5MxlIokYWxIrzRH1LRj+TyZ+YaQ=";

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
