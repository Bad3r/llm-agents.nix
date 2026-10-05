{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  bun2nixLib,
  makeWrapper,
  installAgentSkills,
  mkUpdater,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenvNoCC.mkDerivation {
  pname = "agent-slack";
  inherit version;

  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "agent-slack";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nixLib.hook
    makeWrapper
    installAgentSkills
  ];

  bunDeps = bun2nixLib.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  dontUseBunBuild = true;
  dontUseBunInstall = true;
  # prepare runs simple-git-hooks
  dontRunLifecycleScripts = true;

  buildPhase = ''
    runHook preBuild
    bun build src/index.ts --target=bun --outfile dist/agent-slack.js \
      --define 'AGENT_SLACK_BUILD_VERSION="${version}"'
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 dist/agent-slack.js $out/lib/agent-slack/agent-slack.js
    makeWrapper ${lib.getExe bun} $out/bin/agent-slack \
      --add-flags "$out/lib/agent-slack/agent-slack.js"
    runHook postInstall
  '';

  # Export the CLI guide and its references without running the HOME installer.
  dontInstallAgentSkills = true;
  postInstall = ''
    installSkill skills/agent-slack
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  postInstallCheck = ''
    test -f "$out/share/skills/agent-slack/agent-slack/SKILL.md"
    test -f "$out/share/skills/agent-slack/agent-slack/references/targets.md"
    test -f "$out/share/skills/agent-slack/agent-slack/references/output.md"
  '';

  passthru.category = "Utilities";
  passthru.updater = mkUpdater {
    kind = "bun-github";
    purl = "pkg:github/stablyai/agent-slack";
  };

  meta = {
    description = "Slack automation CLI for AI agents";
    homepage = "https://github.com/stablyai/agent-slack";
    changelog = "https://github.com/stablyai/agent-slack/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = [ lib.maintainers.ramblurr ];
    mainProgram = "agent-slack";
    inherit (bun.meta) platforms;
  };
}
