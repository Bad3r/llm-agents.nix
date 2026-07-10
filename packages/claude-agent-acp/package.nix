{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "claude-agent-acp";
  version = "0.58.1";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    tag = "v${version}";
    hash = "sha256-9bnUVYfE3iMOcHFg9PK25MoMla978/YbkZLzWgVkd84=";
  };

  npmDepsHash = "sha256-z2dSmspOx+JoO8vd+vSnJJVPmCo//TdgFZrkFuV1ee8=";
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by the Claude Code SDK (TypeScript)";
    homepage = "https://github.com/agentclientprotocol/claude-agent-acp";
    changelog = "https://github.com/agentclientprotocol/claude-agent-acp/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude-agent-acp";
    platforms = platforms.all;
  };
}
