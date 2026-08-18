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
  version = "0.30.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    tag = "v${version}";
    hash = "sha256-KQraN1W6CvY6Wl6s0BFAWu1QGQftfpcPPPbqLNQQRkU=";
  };

  vendorHash = "sha256-KbX9VmU/YzDus8bP4Ia8f7Q/IhncPJDoEQdL+dhJMFY=";

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
