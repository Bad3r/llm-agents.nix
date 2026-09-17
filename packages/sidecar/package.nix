{
  lib,
  flake,
  buildGo127Module,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGo127Module rec {
  pname = "sidecar";
  version = "1.14.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-CRU8goMGWUbELCSVsDYDFk24VkTuDTt0waVlm92PNsM=";
  };

  vendorHash = "sha256-VOnnjbhOdQBhxIPRkBUKoKX0OpW3PXcOJudsZPJuDMY=";

  subPackages = [ "cmd/sidecar" ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${version}"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal-based development companion for AI coding agents";
    homepage = "https://github.com/marcus/sidecar";
    changelog = "https://github.com/marcus/sidecar/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "sidecar";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
