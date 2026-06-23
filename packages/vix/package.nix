{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "vix";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "get-vix";
    repo = "vix";
    rev = "v${version}";
    hash = "sha256-dlW07swW66Qkc7K0Ugt+dyqJnHE4cKiPOXIlEkAqiO8=";
  };

  # source already has vendor folder
  vendorHash = null;

  subPackages = [
    "cmd/vix"
    "cmd/vixd"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Sleek, Fast and Token Efficient AI Coding Agent";
    homepage = "https://github.com/get-vix/vix";
    changelog = "https://github.com/get-vix/vix/releases/tag/v${version}";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ daspk04 ];
    mainProgram = "vix";
    platforms = platforms.unix;
  };
}
