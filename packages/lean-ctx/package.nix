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
  version = "3.9.17";

  src = fetchFromGitHub {
    owner = "yvgude";
    repo = "lean-ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZL3TwTtUj13H3b0ymZYxByeJLPwKmdu6ommjKJxAVPM=";
  };

  cargoRoot = "rust";
  buildAndTestSubdir = "rust";
  cargoHash = "sha256-XYHhor0SXS7v2j/379nb9XB9wD/YYFPm3AD97FvoqEY=";

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

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
