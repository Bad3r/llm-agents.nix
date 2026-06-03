{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
}:

buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.27.0";

  src = fetchFromGitHub {
    owner = "Nano-Collective";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-YlFDjuOEPBYbLhb7Ipb4fAO65a4PoICCv3azRMJcztw=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-n3PC1HYUbd6awcD7sIq5TE2US7mJzaFWjbpHZDy99Ao=";
    # Upstream lockfile has stale patchedDependencies not in package.json
    postPatch = ''
      sed -i '/^patchedDependencies:/,/^$/d' pnpm-lock.yaml
    '';
  };

  postPatch = ''
    sed -i '/^patchedDependencies:/,/^$/d' pnpm-lock.yaml
  '';

  nativeBuildInputs = [ pnpm ];
  npmConfigHook = pnpmConfigHook;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  dontNpmPrune = true; # hangs forever on both Linux/darwin

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A beautiful local-first coding agent running in your terminal - built by the community for the community ⚒";
    homepage = "https://github.com/Nano-Collective/nanocoder";
    changelog = "https://github.com/Nano-Collective/nanocoder/releases";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "nanocoder";
  };
}
