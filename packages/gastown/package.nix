{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  beads,
  dolt,
  gitMinimal,
  icu,
  sqlite,
  tmux,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "gastown";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gastown";
    rev = "v${version}";
    hash = "sha256-JM5WkrTBdOyv4kCd+jlXpfOjjkzcMUn9XYjD9p8WgHA=";
  };

  vendorHash = "sha256-eiG+t0Iw3xZCX77fXA95P3EtrcVeacOixPVEdHXt0NY=";

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ icu ];

  subPackages = [ "cmd/gt" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/steveyegge/gastown/internal/cmd.Version=${version}"
    "-X=github.com/steveyegge/gastown/internal/cmd.Build=release"
    "-X=github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
  ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/gt \
      --prefix PATH : ${
        lib.makeBinPath [
          beads
          dolt
          gitMinimal
          sqlite
          tmux
        ]
      }
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Gas Town - multi-agent workspace manager";
    homepage = "https://github.com/gastownhall/gastown";
    changelog = "https://github.com/gastownhall/gastown/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zaninime ];
    mainProgram = "gt";
    platforms = platforms.unix;
  };
}
