{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "sidecar";
  version = "0.92.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-g4dKG2bhLgPtgjVZOg1lw1lgSGEx9RMZ+2UB0IqpYJE=";
  };

  vendorHash = "sha256-Kvnn3s+8wjBqvfRv6V5FZ1uwuFG+5QmKWlOwjvuKmFI=";

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
