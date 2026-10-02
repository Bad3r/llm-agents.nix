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
  version = "2.2.5";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sK66x5OWp+SnD2uKjvrHPg3uCd3MaVltoIvSPCSJ48w=";
  };

  cargoHash = "sha256-WflmXZ5EzQcYVcbQu28h1GY4T8DReTRPym8btfv7oQo=";

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
