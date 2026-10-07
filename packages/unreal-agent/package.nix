{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  go_1_27,
}:

(buildGoModule.override { go = go_1_27; }) rec {
  pname = "unreal-agent";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "unreallabsai";
    repo = "unreal-agent";
    tag = "v${version}";
    hash = "sha256-VlHbwr9wg5Z4xvjsYmluT189HCgEUBcqhe5jxTEY9CQ=";
  };

  vendorHash = "sha256-B7sXtnSGKwwfJuLujb9+/PH8FY8Hzk/uiI5vuJedWKI=";

  subPackages = [ "cmd/unreal-agent-runner" ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = true;

  # The runner exposes help but no version flag.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/unreal-agent-runner -h >/dev/null
    runHook postInstallCheck
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Async-first agent harness";
    homepage = "https://github.com/unreallabsai/unreal-agent";
    changelog = "https://github.com/unreallabsai/unreal-agent/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ vidhanio ];
    mainProgram = "unreal-agent-runner";
    platforms = platforms.unix;
  };
}
