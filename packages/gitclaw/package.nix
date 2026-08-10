{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "gitclaw";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "open-gitagent";
    repo = "gitagent";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jfXqId3rdDmnjw9ZlsU+/VC8JJZdaOYnvkQn8U6Zmn0=";
  };

  npmDepsHash = "sha256-8fkC/HV6U3HyI05gMMz1T6k4LIp1qGPug04+CFImaI4=";
  makeCacheWritable = true;

  # @googleworkspace/cli's postinstall downloads a prebuilt `gws` binary from
  # GitHub releases, which the sandbox blocks during both `npm rebuild` and
  # `npm prune`. Nothing in src/ imports the package — it is only declared so
  # user hook scripts can shell out to `gws` — so skip lifecycle scripts
  # globally and drop the dangling stub from the final closure.
  npmFlags = [ "--ignore-scripts" ];
  preFixup = ''
    rm -f $out/lib/node_modules/gitclaw/node_modules/.bin/gws
    rm -rf $out/lib/node_modules/gitclaw/node_modules/@googleworkspace
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Universal git-native multimodal AI agent (formerly gitagent)";
    homepage = "https://github.com/open-gitagent/gitagent";
    changelog = "https://github.com/open-gitagent/gitagent/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "gitclaw";
    platforms = lib.platforms.all;
  };
})
