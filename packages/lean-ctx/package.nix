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
  version = "3.12.0";

  src = fetchFromGitHub {
    owner = "yvgude";
    repo = "lean-ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Nod1Bx5iU0I+MiVV74lzllW9Nr1hkhNZK84XV3Nt1Kg=";
  };

  cargoRoot = "rust";
  buildAndTestSubdir = "rust";
  cargoHash = "sha256-1+y3EtkFITSWhRMHWoQXFhL6a3P9LI7Xqy1RzRR2f5Y=";

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
