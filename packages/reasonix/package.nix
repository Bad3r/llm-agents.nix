{
  pkgs,
  lib,
  flake,
  versionCheckHook,
  versionCheckHomeHook,
  ...
}:
# Upstream rewrote reasonix from TypeScript to Go in 1.0.0.
pkgs.buildGoModule (finalAttrs: {
  pname = "reasonix";
  version = "1.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    rev = "v${finalAttrs.version}";
    hash = "sha256-UHVHiCPbY6+JGwYRabAEsT1fLj0cumeyr4clGWkwlXM=";
  };

  vendorHash = "sha256-ObDfNr9Olc6mFfIYx3yb4UxesZD+HXzN7mjxr/iT2p4=";

  subPackages = [ "cmd/reasonix" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  meta = {
    description = "DeepSeek-native AI coding agent for your terminal";
    homepage = "https://github.com/esengine/DeepSeek-Reasonix";
    license = lib.licenses.mit;
    changelog = "https://github.com/esengine/DeepSeek-Reasonix/releases/tag/v${finalAttrs.version}";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ arch-fan ];
    mainProgram = "reasonix";
    platforms = lib.platforms.unix;
  };

  passthru = {
    category = "AI Coding Agents";
  };
})
