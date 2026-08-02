{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "td";
  version = "0.55.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "td";
    tag = "v${version}";
    hash = "sha256-PJy2sWqN5HWppM7WHsL8QS/4Cz8uXjjYqX4np5tuGV4=";
  };

  vendorHash = "sha256-/IWBYL+WfLz7vDdUs//0KY8rb9mOv4S1jBXCZbYxJRo=";

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
    description = "A minimalist CLI for tracking tasks across AI coding sessions.";
    homepage = "https://github.com/marcus/td";
    changelog = "https://github.com/marcus/td/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "td";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
