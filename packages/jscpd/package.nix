{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installAgentSkills,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "jscpd";
  version = "5.4.1";

  src = fetchFromGitHub {
    owner = "kucherenko";
    repo = "jscpd";
    tag = "v${version}";
    hash = "sha256-TTTD+GwvsixXKE0RX4u67J+3x54KB8yjpyNcJ1an9WA=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-ICchwVxU8OnGezzVW7zCqGYpjpW5Z4xzp0kGmHHbuuM=";

  cargoBuildFlags = [
    "-p"
    "jscpd"
  ];

  nativeBuildInputs = [ installAgentSkills ];
  dontInstallAgentSkills = true;

  postInstall = ''
    # The Rust source root excludes the sibling skills in the full source tree.
    # Keep their directory names so relative links between skills still work.
    for skill in jscpd dry-refactoring codebase-refactoring compare-codebases code-migration; do
      installSkill "${src}/skills/$skill"
      substituteInPlace "$out/share/skills/jscpd/$skill/SKILL.md" \
        --replace-fail 'npx jscpd' 'jscpd'
    done

    # This inline command is wrapped across two Markdown source lines upstream.
    substituteInPlace "$out/share/skills/jscpd/codebase-refactoring/SKILL.md" \
      --replace-fail $'npx\njscpd --dashboard' 'jscpd --dashboard'
  '';

  # Workspace tests exercise fixtures outside the rust/ source root.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  postInstallCheck = ''
    for skill in jscpd dry-refactoring codebase-refactoring compare-codebases code-migration; do
      test -f "$out/share/skills/jscpd/$skill/SKILL.md"
      if grep -F 'npx jscpd' "$out/share/skills/jscpd/$skill/SKILL.md"; then
        echo "Unexpected npm invocation in $skill" >&2
        exit 1
      fi
    done
  '';

  passthru.category = "Code Review";

  meta = {
    description = "Copy/paste detector for programming source code";
    homepage = "https://jscpd.dev";
    changelog = "https://github.com/kucherenko/jscpd/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ mic92 ];
    mainProgram = "jscpd";
    platforms = lib.platforms.all;
  };
}
