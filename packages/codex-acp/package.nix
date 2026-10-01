{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  codex,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "codex-acp";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    tag = "v${version}";
    hash = "sha256-VdC7g7qkgLnFMtga0uwtNd5ZxsT1xc75GEd++kBZXbA=";
  };

  npmDepsHash = "sha256-X8C9lmKyM9Xo7I3k9mbRDvix2OPWSIyHXMw7x6IHgv0=";
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  # The bundled @openai/codex npm dependency ships prebuilt binaries that are
  # not usable on NixOS; point the adapter at this flake's codex package
  # instead, unless the user overrides CODEX_PATH themselves.
  postInstall = ''
    wrapProgram $out/bin/codex-acp \
      --set-default CODEX_PATH ${lib.getExe codex}
  '';

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "ACP-compatible coding agent powered by the Codex App Server";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    changelog = "https://github.com/agentclientprotocol/codex-acp/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "codex-acp";
    platforms = platforms.all;
  };
}
