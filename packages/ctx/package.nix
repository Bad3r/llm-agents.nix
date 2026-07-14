{
  lib,
  fetchFromGitHub,
  flake,
  rustPlatform,
  pkg-config,
  openssl,
  stdenv,
  libiconv,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ctx";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BaZvBlRE8PkUgacWDoNhR14YoenfKKKAoCZQUrv6TQk=";
  };

  cargoHash = "sha256-aOd7zN8U2w/nkoTxUUDrllngtUWZ/3KhGYIAJDa5F5w=";

  cargoBuildFlags = [
    "--package"
    "ctx"
  ];

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

  cargoTestFlags = finalAttrs.cargoBuildFlags;

  # CoreML acquisition tests fail in Nix sandbox.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Search the coding agent history already on your machine";
    homepage = "https://github.com/ctxrs/ctx";
    changelog = "https://github.com/ctxrs/ctx/releases/tag/v${finalAttrs.version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "ctx";
    platforms = platforms.unix;
  };
})
