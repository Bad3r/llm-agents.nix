{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
  versionCheckHook,
}:

buildNpmPackage rec {
  npmDepsFetcherVersion = 2;
  pname = "codegraph";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "colbymchenry";
    repo = "codegraph";
    rev = "v${version}";
    hash = "sha256-c0n6sr2SKTBk70ouGWMLzqd15tYVvWRQFSI49BIm9AQ=";
  };

  npmDepsHash = "sha256-peOosh94xQHDx2hpr296KsnrFi5vGTN+BfLIkJcII4c=";
  makeCacheWritable = true;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.category = "Memory & Code Intelligence";

  meta = {
    description = "Semantic code intelligence for AI coding agents";
    homepage = "https://github.com/colbymchenry/codegraph";
    changelog = "https://github.com/colbymchenry/codegraph/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ Bad3r ];
    mainProgram = "codegraph";
    platforms = lib.platforms.all;
  };
}
