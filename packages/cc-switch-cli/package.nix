{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "cc-switch-cli";
  version = "5.9.3";

  src = fetchFromGitHub {
    owner = "SaladDay";
    repo = "cc-switch-cli";
    tag = "v${version}";
    hash = "sha256-SQrr8CcwOwIDRCBohZGOepK4xg+qxBC7zCqC3Jmpu7I=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-wElWf7UivUwL/GDaYclOSmehIy7kMxUz+b8Q3jwCuXk=";

  # Tests require network access and runtime configuration
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "CLI version of CC Switch - All-in-One Assistant for Claude Code, Codex & Gemini CLI";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    changelog = "https://github.com/SaladDay/cc-switch-cli/releases/tag/v${version}";
    downloadPage = "https://github.com/SaladDay/cc-switch-cli/releases";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ zrubing ];
    mainProgram = "cc-switch";
    platforms = platforms.unix;
  };
}
