{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  flake,
  makeWrapper,
  ripgrep,
  bubblewrap,
  versionCheckHook,
  versionCheckHomeHook,
}:

# Upstream rewrote reasonix from TypeScript to Go in 1.0.0.
buildGoModule rec {
  pname = "reasonix";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    rev = "v${version}";
    hash = "sha256-NcKZLH2TQTxujGHmVhoYZUW+P/Z63UiDwQ8phViqZEc=";
  };

  vendorHash = "sha256-ObDfNr9Olc6mFfIYx3yb4UxesZD+HXzN7mjxr/iT2p4=";

  subPackages = [ "cmd/reasonix" ];

  nativeBuildInputs = [ makeWrapper ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
  ];

  doCheck = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  postFixup = ''
    wrapProgram $out/bin/reasonix \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      ${lib.optionalString stdenv.hostPlatform.isLinux "--suffix PATH : ${lib.makeBinPath [ bubblewrap ]}"}
  '';

  meta = {
    description = "DeepSeek-native AI coding agent for your terminal";
    homepage = "https://github.com/esengine/DeepSeek-Reasonix";
    license = lib.licenses.mit;
    changelog = "https://github.com/esengine/DeepSeek-Reasonix/releases/tag/v${version}";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ arch-fan ];
    mainProgram = "reasonix";
    platforms = lib.platforms.unix;
  };

  passthru.category = "AI Coding Agents";
}
