{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  libgit2,
  bash,
  installAgentSkills,
  versionCheckHook,
  flake,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tuicr";
  version = "0.27.0";

  src = fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kObt0MLJZYASWM1vexZTPaIeFaU2XpT9sHUSdClRz2Y=";
  };

  cargoHash = "sha256-azgmxJP3iQO+WfJCWqfi19rCSb6D0a0luWcgEW+8Sbg=";

  nativeBuildInputs = [
    pkg-config
    installAgentSkills
  ];

  buildInputs = [
    bash
    libgit2
  ];

  doCheck = false;

  # Keep the helper beside its wrappers; optional multiplexers remain on PATH.
  dontInstallAgentSkills = true;
  postInstall = ''
    installSkill skills/tuicr
    patchShebangs --host "$out/share/skills/tuicr/tuicr"/tuicr-wrapper*.sh
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  postInstallCheck = ''
    skillDir="$out/share/skills/tuicr/tuicr"
    test -f "$skillDir/SKILL.md"
    test -f "$skillDir/_tuicr-common.sh"
    test ! -x "$skillDir/_tuicr-common.sh"
    for script in tuicr-wrapper{,-cmux,-zellij,-herdr}.sh; do
      test -x "$skillDir/$script"
      grep -Eq '^#!/nix/store/[^ ]+/bin/bash$' "$skillDir/$script"
      grep -Fq "$script" "$skillDir/SKILL.md"
      grep -Fq '/_tuicr-common.sh"' "$skillDir/$script"
      "$skillDir/$script" --help > /dev/null
    done
  '';

  passthru.category = "Code Review";

  meta = {
    description = "Review AI-generated diffs like a GitHub pull request, right from your terminal";
    homepage = "https://github.com/agavra/tuicr";
    changelog = "https://github.com/agavra/tuicr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "tuicr";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    maintainers = with flake.lib.maintainers; [ ypares ];
  };
})
