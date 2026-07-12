{
  lib,
  flake,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildNpmPackage rec {
  pname = "gnhf";
  version = "0.1.42";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "gnhf";
    rev = "gnhf-v${version}";
    hash = "sha256-8dTfXCULAoXMJwb38bEMCazT7jzT130rzpLivVkx3Wc=";
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-kQHYvZ8LNHGw1pPuTnOTUn26yUY8TmgA0+BO2+cSvLY=";
  };

  nativeBuildInputs = [ pnpm ];
  npmConfigHook = pnpmConfigHook;

  # npm prune hangs forever in pnpm-managed node_modules
  dontNpmPrune = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Ralph/autoresearch-style orchestrator that keeps coding agents running while you sleep";
    homepage = "https://github.com/kunchenguid/gnhf";
    changelog = "https://github.com/kunchenguid/gnhf/releases/tag/gnhf-v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ pikdum ];
    mainProgram = "gnhf";
    platforms = platforms.all;
  };
}
