{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
  versionCheckHook,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "oh-my-claudecode";
  version = "5.7.16";

  src = fetchFromGitHub {
    owner = "yeachan-heo";
    repo = "oh-my-claudecode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9m+vWaOijHylBDQerV//GTi4SlrbBC2XNhIyP9iRpe4=";
  };

  npmDepsHash = "sha256-0WKr1Ch8NWEy6Ar/AWih98LN3Hhc87Fxd86lWeU6TL8=";
  makeCacheWritable = true;

  # Native deps (better-sqlite3, @ast-grep/napi) need rebuild skipped
  npmFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Claude Code Ecosystem";

  meta = {
    description = "Multi-agent orchestration system for Claude Code";
    homepage = "https://github.com/yeachan-heo/oh-my-claudecode";
    changelog = "https://github.com/yeachan-heo/oh-my-claudecode/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "oh-my-claudecode";
    platforms = lib.platforms.all;
  };
})
