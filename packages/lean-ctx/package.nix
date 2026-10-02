{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "lean-ctx";
  version = "3.10.5";

  src = fetchFromGitHub {
    owner = "yvgude";
    repo = "lean-ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-J/pMPjvaKHv7q/WghgVQmSGY+jjm0yozFOpVSblcCN4=";
  };

  cargoRoot = "rust";
  buildAndTestSubdir = "rust";
  cargoHash = "sha256-Po0pIbP9E1mS3tTGvxDb1Bigpx7BgBbgGFY9E6DFjrE=";

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  # Upstream's fat LTO with codegen-units=1 is a single-threaded link that
  # exceeds the aarch64 builder's 1200s timeout.
  env = {
    CARGO_PROFILE_RELEASE_LTO = "off";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
  };

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Memory & Code Intelligence";

  meta = {
    description = "Context OS for AI development — compression, memory, and routing for LLM context";
    homepage = "https://github.com/yvgude/lean-ctx";
    changelog = "https://github.com/yvgude/lean-ctx/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ csanthiago ];
    mainProgram = "lean-ctx";
    platforms = lib.platforms.unix;
  };
})
