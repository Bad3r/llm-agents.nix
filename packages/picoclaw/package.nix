{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  olm,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule rec {
  pname = "picoclaw";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "sipeed";
    repo = "picoclaw";
    tag = "v${version}";
    hash = "sha256-pdI6SS05aPiuqAflJW7kVk49ljDA+CXuo9syoyRBBTw=";
  };

  vendorHash = "sha256-mN+eI8JtqIqBCxheVlTw7nL200WgVAd8xLhUsrYdohE=";

  nativeBuildInputs = [ unpinGoModVersionHook ];

  # mautrix-go crypto backend links libolm via cgo. libolm is marked
  # insecure in nixpkgs (deprecated upstream, timing side-channels in
  # its AES/SHA primitives). Accepted here because Matrix is an optional
  # chat backend and the pure-Go goolm alternative is still experimental.
  buildInputs = [
    (olm.overrideAttrs (old: {
      meta = old.meta // {
        knownVulnerabilities = [ ];
      };
    }))
  ];

  postPatch = ''
    # go:embed in cmd/picoclaw/internal/onboard/command.go expects a workspace
    # directory copied there by go:generate which doesn't run during nix builds
    cp -r workspace cmd/picoclaw/internal/onboard/workspace
  '';

  subPackages = [ "cmd/picoclaw" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/sipeed/picoclaw/pkg/config.Version=${version}"
  ];

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  versionCheckProgramArg = "version";
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Assistants";

  meta = {
    description = "Tiny, fast, and deployable anywhere — automate the mundane, unleash your creativity";
    homepage = "https://picoclaw.io";
    changelog = "https://github.com/sipeed/picoclaw/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "picoclaw";
    platforms = lib.platforms.unix;
  };
}
