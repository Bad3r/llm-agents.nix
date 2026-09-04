{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tokscale";
  version = "4.15.1";

  src = fetchFromGitHub {
    owner = "junhoyeo";
    repo = "tokscale";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FgmZuozZySdDOjIt3ayR6SKeikpuS7DomTI4pd84Isw=";
  };

  cargoHash = "sha256-ykKjcTpuOPfUbZqZPjsdz5dcE0pdaTyRhle6QI89xis=";

  env.OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  # Tests need network access.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Usage Analytics";

  meta = {
    description = "CLI and TUI for AI token usage analytics";
    homepage = "https://github.com/junhoyeo/tokscale";
    changelog = "https://github.com/junhoyeo/tokscale/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "tokscale";
    platforms = lib.platforms.unix;
  };
})
