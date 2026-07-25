{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "sidecar";
  version = "0.87.1";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-LG2tmKt1AG4OCk+KIv1S+Eyrx84eC14KWW8/7To+S/Y=";
  };

  vendorHash = "sha256-qYZWm6DeB5DOIzdCHOEVCVfVwJhXInEJomgtKjI5dYI=";

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
