{
  lib,
  buildGoModule,
  fetchFromGitHub,
  flake,
  go-bin,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

# entireio/auth-go requires a go >= 1.26.4 toolchain, but nixpkgs only ships
# 1.26.3 so far; go-bin tracks the latest upstream patch release.
(buildGoModule.override { go = go-bin; }) rec {
  pname = "entire";
  version = "0.11.5";

  src = fetchFromGitHub {
    owner = "entireio";
    repo = "cli";
    tag = "v${version}";
    hash = "sha256-MpTJt9HyEWkPGZIBST+iop0iCHHfy/4Hw3T5TmwB6Yo=";
  };

  nativeBuildInputs = [ unpinGoModVersionHook ];

  vendorHash = "sha256-SgjJ2+eXUzN5YAafVII7Lgj9i2s1JDRBLanNNvhP0gA=";

  subPackages = [ "./cmd/entire" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/entireio/cli/cmd/entire/cli/versioninfo.Version=${version}"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "version" ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "CLI tool that captures AI agent sessions and links them to code changes";
    homepage = "https://github.com/entireio/cli";
    changelog = "https://github.com/entireio/cli/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ yutakobayashidev ];
    mainProgram = "entire";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
