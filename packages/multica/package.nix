{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "multica";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "multica-ai";
    repo = "multica";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4nhCKbODP0Lbdl7pNkK0/eYgbL/HMyCUZlps+DGqbHs=";
  };

  sourceRoot = "${finalAttrs.src.name}/server";
  subPackages = [ "cmd/multica" ];

  vendorHash = "sha256-b6elV4j+7R6L29q8tbCI3MAOY8X63ndzlmCMv7jo7mM=";

  ldflags = [ "-X main.version=${finalAttrs.version}" ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Assistants";

  meta = {
    description = "Command-line interface for the Multica platform";
    homepage = "https://github.com/multica-ai/multica";
    changelog = "https://github.com/multica-ai/multica/releases/tag/v${finalAttrs.version}";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "multica";
    platforms = lib.platforms.unix;
  };
})
