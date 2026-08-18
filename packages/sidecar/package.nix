{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "sidecar";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-IhJw76jTlUpC8oAvlRbv5gMDmzDkupycXAlidhpUDZQ=";
  };

  vendorHash = "sha256-Y/6CnuGpOKUH/dqcTxoVBx55EnyCqCrru723zu48Z64=";

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
