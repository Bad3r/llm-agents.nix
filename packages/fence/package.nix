{
  lib,
  flake,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  makeWrapper,
  versionCheckHook,
  versionCheckHomeHook,
  # Linux dependencies
  bubblewrap,
  socat,
  bpftrace,
}:

buildGoModule rec {
  pname = "fence";
  version = "0.1.63";

  src = fetchFromGitHub {
    owner = "fencesandbox";
    repo = "fence";
    tag = "v${version}";
    hash = "sha256-PxmFqy3oejLhkxrav378YRPzj07AzQUan7hbzcw8HPc=";
  };

  vendorHash = "sha256-iIDgAa2W2jsGSTGFx6PNDePjlI7Bgouys+YU0gFX7yg=";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  subPackages = [ "cmd/fence" ];

  doCheck = false;

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
    "-X=main.buildTime=1970-01-01T00:00:00Z"
    "-X=main.gitCommit=v${version}"
  ];

  postInstall = ''
    installShellCompletion --cmd fence \
      --bash <($out/bin/fence completion bash) \
      --fish <($out/bin/fence completion fish) \
      --zsh <($out/bin/fence completion zsh)
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/fence \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          socat
          bpftrace
        ]
      }
  '';

  passthru.category = "Sandboxing & Isolation";

  meta = with lib; {
    description = "Lightweight, container-free sandbox for running commands with network and filesystem restrictions";
    homepage = "https://fencesandbox.com/";
    changelog = "https://github.com/fencesandbox/fence/releases";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ uesyn ];
    mainProgram = "fence";
  };
}
