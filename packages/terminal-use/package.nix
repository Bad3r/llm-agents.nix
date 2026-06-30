{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwinMinVersionHook,
  nix-update-script,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "terminal-use";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "flipbit03";
    repo = "terminal-use";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wHu+L//x1NiXTxD2mas0niV/TbTezg4MC7wUWAfgxpY=";
  };

  cargoHash = "sha256-KapRznQ67o8H0aIMGvCMojwF/qSZ3rSlx6SEKbi12ig=";

  # `tu self update` rewrites its own binary (or shells out to `cargo install`),
  # which is wrong for a Nix-managed install. Make it refuse and defer to Nix.
  patches = [ ./disable-self-update.patch ];

  # The Cargo manifest ships a placeholder 0.0.0 version that the release
  # workflow rewrites at tag time. Stamp the real version so `tu --version`
  # (built from CARGO_PKG_VERSION) reports the packaged release.
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'version = "0.0.0"' 'version = "${finalAttrs.version}"'
  '';

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    (darwinMinVersionHook "11.0")
  ];

  # The Cargo manifest carries a placeholder 0.0.0 version that the release
  # workflow rewrites at tag time, so `tu --version` reports the git tag.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru = {
    updateScript = nix-update-script { };
    category = "Utilities";
  };

  meta = {
    description = "Headless virtual terminal for AI agents";
    longDescription = ''
      tu is a full terminal emulator for AI agents. It spawns interactive
      terminal apps and lets an agent read the rendered screen (as text or PNG
      screenshot) and drive the keyboard and mouse — no GUI, X server, or
      display needed. Multiple sessions can run at once, like tmux for an
      agent.
    '';
    homepage = "https://github.com/flipbit03/terminal-use";
    changelog = "https://github.com/flipbit03/terminal-use/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "tu";
    maintainers = with lib.maintainers; [ mic92 ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
