{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "mindwalk";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "cosmtrek";
    repo = "mindwalk";
    tag = "v${version}";
    hash = "sha256-kKqW+yeHYR1eZopxspJ8xiZszQcrW+MvMBynhbtzKpU=";
  };

  vendorHash = "sha256-qVoj03LNLbdoCUAOydK7oEHsuZ1BZ6Z2jwYB3gPOfrw=";

  # The pre-built web UI is committed at the tag under
  # internal/server/static, so no npm build is needed.
  subPackages = [ "cmd/mindwalk" ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Visualization tool that replays coding-agent sessions on a 3D map of your codebase";
    homepage = "https://github.com/cosmtrek/mindwalk";
    changelog = "https://github.com/cosmtrek/mindwalk/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "mindwalk";
    platforms = platforms.unix;
  };
}
