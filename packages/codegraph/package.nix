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
  version = "1.6.2";

  src = fetchFromGitHub {
    owner = "colbymchenry";
    repo = "codegraph";
    tag = "v${version}";
    hash = "sha256-G/rBBP1dk1JB17Y4+xubUlPd3iDU2oKLuoiaxZh6Lnw=";
  };

  npmDepsHash = "sha256-QA28P/ek+55IO4AkZFVm8sd8uyxjKlUuCFnF6XFLTzA=";
  makeCacheWritable = true;

  # build:ui runs the ui workspace through a nested `npm run`, where the root
  # node_modules/.bin precedes the workspace's in PATH. That picks the hoisted
  # vite 5 (for vitest) over the vite 7 the ui's svelte plugin needs.
  postPatch = ''
    substituteInPlace ui/package.json \
      --replace-fail '"build": "vite build"' '"build": "node node_modules/vite/bin/vite.js build"'
  '';

  # The ui workspace is only needed at build time (emitted to dist/viewer) and
  # is not installed, which leaves its node_modules link dangling.
  postInstall = ''
    rm $out/lib/node_modules/@colbymchenry/codegraph/node_modules/@colbymchenry/codegraph-ui
  '';

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
