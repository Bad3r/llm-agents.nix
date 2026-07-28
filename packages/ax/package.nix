{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  bun2nixLib,
  makeWrapper,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenvNoCC.mkDerivation {
  pname = "ax";
  inherit version;

  src = fetchFromGitHub {
    owner = "yusukebe";
    repo = "ax";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nixLib.hook
    makeWrapper
  ];

  bunDeps = bun2nixLib.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # The published bin is src/index.ts run under bun — there is no bundle step.
  dontUseBunBuild = true;
  # The hook defaults, plus --production to keep devDependencies (oxfmt,
  # bun2nix) out of the runtime closure.
  bunInstallFlags = [
    "--linker=isolated"
    "--backend=symlink"
    "--production"
  ];
  # postinstall runs the bun2nix CLI to regenerate nix/bun.nix, which is
  # pointless (and fails) in the sandbox.
  dontRunLifecycleScripts = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/ax
    cp -r src node_modules package.json $out/share/ax/

    makeWrapper ${lib.getExe bun} $out/bin/ax \
      --add-flags "$out/share/ax/src/index.ts"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "The AI-era curl: fetch, discover, extract. One command";
    homepage = "https://github.com/yusukebe/ax";
    changelog = "https://github.com/yusukebe/ax/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ax";
    platforms = platforms.unix;
  };
}
