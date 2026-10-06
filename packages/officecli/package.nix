{
  lib,
  flake,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  installAgentSkills,
  versionCheckHook,
}:

buildDotnetModule rec {
  pname = "officecli";
  version = "1.0.155";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "OfficeCLI";
    tag = "v${version}";
    hash = "sha256-LbCA7qWK0zq1X+Z5eplzFdt5Z1E1Bey1tbxNQ7odKdQ=";
  };

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  projectFile = "src/officecli/officecli.csproj";
  executables = [ "officecli" ];
  nugetDeps = ./deps.json;

  nativeBuildInputs = [ installAgentSkills ];
  dontInstallAgentSkills = true;

  postInstall = ''
    installSkill skills/officecli
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  postInstallCheck = ''
    test -f "$out/share/skills/officecli/officecli/SKILL.md"
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "CLI for creating and editing Office Open XML documents";
    homepage = "https://github.com/iOfficeAI/OfficeCLI";
    changelog = "https://github.com/iOfficeAI/OfficeCLI/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "officecli";
    platforms = platforms.unix;
  };
}
