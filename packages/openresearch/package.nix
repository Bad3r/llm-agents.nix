{
  lib,
  flake,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  mkUpdater,
  bash,
  coreutils,
  gawk,
  git,
  gnutar,
  openssh,
  procps,
  xdg-utils,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  hashes = builtins.fromJSON (builtins.readFile ./hashes.json);
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openresearch";
  inherit (hashes) version cargoHash;

  src = fetchFromGitHub {
    owner = "alphaXiv";
    repo = "OpenResearch";
    tag = "v${finalAttrs.version}";
    inherit (hashes) hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace $(grep -rl '#!/bin/sh' src) \
      --replace-fail '#!/bin/sh' '#!${bash}/bin/sh'
    substituteInPlace src/commands/up.rs \
      --replace-fail '"sh",' '"${bash}/bin/sh",'
  '';

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  nativeCheckInputs = [
    bash
    coreutils
    gawk
    git
    gnutar
    openssh
    procps
  ];

  postInstall = ''
    wrapProgram $out/bin/orx \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            bash
            coreutils
            git
            gnutar
            openssh
            procps
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [ xdg-utils ]
        )
      } \
      --set OPENRESEARCH_CLI_DISABLE_UPDATE 1 \
      --set ORX_NO_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru = {
    category = "Workflow & Project Management";
    updater = mkUpdater {
      kind = "github-source";
      purl = "pkg:github/alphaXiv/OpenResearch";
      depHashKey = "cargoHash";
    };
  };

  meta = with lib; {
    description = "Local-first workspace for research agents and autoresearch";
    homepage = "https://openresearch.sh/";
    changelog = "https://github.com/alphaXiv/OpenResearch/releases/tag/v${finalAttrs.version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "orx";
    platforms = platforms.unix;
  };
})
