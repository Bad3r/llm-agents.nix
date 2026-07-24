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
  version = "0.28.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    tag = "v${version}";
    hash = "sha256-1Q4xrGutQnhyF6kF21hUsRTRcKhJ0VHDUUoZe87k4cw=";
  };

  vendorHash = "sha256-/pe+fZDPsw4A6ZobeiR85VXDyzbB4pLfir9prInpLeo=";

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
