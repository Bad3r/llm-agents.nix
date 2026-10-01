{
  lib,
  flake,
  buildGo127Module,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGo127Module rec {
  pname = "sidecar";
  version = "1.15.1";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-z0c3ZDVtGGeCkC1+ileY576JLM2O8TE2ZQnydjGpbeI=";
  };

  vendorHash = "sha256-85CNMeHv95fIkpBS6WHLCqdNSZUr6Qg3jgE/DGX4Jqc=";

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
