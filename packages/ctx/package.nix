{
  lib,
  fetchFromGitHub,
  flake,
  rustPlatform,
  installAgentSkills,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ctx";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XihSpW86eVALViD9mnSWXHldXI11T9N0uyHdlLXb9GU=";
  };

  cargoHash = "sha256-Jf51SQ7FuC9a55ZIFQlYW2ebsUGE62loiJHYoDVnu5Q=";

  cargoBuildFlags = [
    "--package"
    "ctx"
  ];

  # CoreML acquisition tests fail in Nix sandbox.
  doCheck = false;

  nativeBuildInputs = [ installAgentSkills ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  # The plugin tree contains another copy of the same skill.
  dontInstallAgentSkills = true;
  postInstall = ''
    installSkill skills/ctx
  '';

  postInstallCheck = ''
    test -f "$out/share/skills/ctx/ctx/SKILL.md"
  '';

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
