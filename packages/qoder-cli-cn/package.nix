{
  stdenv,
  fetchurl,
  flake,
  qoder-cli,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version platforms;

  platform = stdenv.hostPlatform.system;
  src = platforms.${platform} or (throw "Unsupported system: ${platform}");
in
# Same bun-compiled binary as qoder-cli, but built for the mainland China
# service: separate release channel/CDN, binary name and account backend.
qoder-cli.overrideAttrs (old: {
  pname = "qoder-cli-cn";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 qoderclicn $out/bin/qoderclicn

    runHook postInstall
  '';

  meta = old.meta // {
    description = "Qoder CLI (mainland China edition) - terminal-based AI coding assistant for China-region accounts";
    homepage = "https://qoder.cn";
    changelog = "https://qoder.cn/changelog";
    downloadPage = "https://qoder.cn/download";
    maintainers = with flake.lib.maintainers; [ RyougiShiki-214 ];
    mainProgram = "qoderclicn";
  };
})
