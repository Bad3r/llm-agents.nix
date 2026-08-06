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
  version = "0.1.66";

  src = fetchFromGitHub {
    owner = "fencesandbox";
    repo = "fence";
    tag = "v${version}";
    hash = "sha256-I3nrM2W21n6YdYnE8OhjqBF0969EaWY0k9U6BJDGFHw=";
  };

  vendorHash = "sha256-WjhfAw8wgxvTbTkYwURm9vN2oSvQWiMP2RhwZDCQ0DU=";

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
