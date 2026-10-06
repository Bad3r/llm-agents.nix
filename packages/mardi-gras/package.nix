{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  go-bin,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "mardi-gras";
  version = "0.34.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    tag = "v${version}";
    hash = "sha256-LUC+SgjAcXK3di8HEU0jjFaQJNJdWB41whi+JAsawZ4=";
  };

  vendorHash = "sha256-Ji7ij19/4akUex2gabqrnWFQlr+XvDlHKVg8FxZQ97A=";

  subPackages = [ "cmd/mg" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal UI for Beads issue tracking with a parade-inspired workflow view";
    homepage = "https://github.com/quietpublish/mardi-gras";
    changelog = "https://github.com/quietpublish/mardi-gras/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "mg";
    platforms = platforms.unix;
  };
}
