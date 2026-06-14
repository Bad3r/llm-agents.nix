{
  lib,
  flake,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  versionCheckHook,
  makeBinaryWrapper,
  unpinGoModVersionHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    npmDepsHash
    vendorHash
    ;

  src = fetchFromGitHub {
    owner = "kenn-io";
    repo = "agentsview";
    rev = "v${version}";
    inherit hash;
  };

  frontend = buildNpmPackage {
    pname = "agentsview-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    inherit npmDepsHash;
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in

buildGoModule {
  pname = "agentsview";
  inherit version src vendorHash;

  nativeBuildInputs = [
    makeBinaryWrapper
    unpinGoModVersionHook
  ];

  subPackages = [ "cmd/agentsview" ];
  tags = [ "fts5" ];
  env.CGO_ENABLED = "1";

  preBuild = ''
    rm -rf internal/web/dist
    cp -r ${frontend} internal/web/dist
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=v${version}"
    "-X main.buildDate=1970-01-01T00:00:00Z"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  postInstall = ''
    wrapProgram $out/bin/agentsview \
      --set AGENTSVIEW_TELEMETRY_ENABLED 0
  '';

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Local-first viewer and analytics for AI coding agent sessions";
    homepage = "https://github.com/kenn-io/agentsview";
    changelog = "https://github.com/kenn-io/agentsview/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ak2k ];
    mainProgram = "agentsview";
    platforms = platforms.unix;
  };
}
