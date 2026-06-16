{
  lib,
  flake,
  stdenv,
  bun2nix,
  bun,
  nodejs,
  fetchFromGitHub,
  fetchNpmDeps,
  makeWrapper,
  autoPatchelfHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    lspToolsMcpNpmHash
    ;

  upstream = fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "oh-my-openagent";
    tag = "v${version}";
    inherit hash;
    # packages/lsp-tools-mcp/ is a git submodule needed for the plugin's
    # built-in `lsp` MCP server.
    fetchSubmodules = true;
  };

  # lsp-tools-mcp is npm-managed (own package-lock.json), so it can't
  # share the top-level bun deps.
  lspToolsMcpDeps = fetchNpmDeps {
    name = "oh-my-opencode-${version}-lsp-tools-mcp-deps";
    src = "${upstream}/packages/lsp-tools-mcp";
    hash = lspToolsMcpNpmHash;
  };
in
stdenv.mkDerivation {
  pname = "oh-my-opencode";
  inherit version;
  src = upstream;

  # Non-empty when upstream ships a stale bun.lock; kept in sync by update.py
  patches = lib.optional (
    builtins.readFile ./fix-stale-bun-lock.patch != ""
  ) ./fix-stale-bun-lock.patch;

  nativeBuildInputs = [
    bun2nix.hook
    bun
    nodejs
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # postinstall downloads platform-specific pre-compiled binaries,
  # prepare runs the build — we handle both ourselves
  dontRunLifecycleScripts = true;
  dontUseBunBuild = true;
  dontUseBunInstall = true;

  # @ast-grep/napi ships binaries for multiple platforms;
  # ignore missing musl libc on glibc systems
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  buildPhase = ''
    runHook preBuild

    # Build the library and CLI bundles. Since 4.9.x upstream split into a
    # monorepo, so the entry points live under packages/omo-opencode/.
    bun build packages/omo-opencode/src/index.ts --outdir dist --target bun --format esm --external @ast-grep/napi --external zod
    bun build packages/omo-opencode/src/cli/index.ts --outdir dist/cli --target bun --format esm --external @ast-grep/napi

    # Generate the config schema (non-fatal if it fails)
    bun run build:schema || true

    # Build the bundled MCP servers (bun workspace packages). git-bash-mcp was
    # added in 4.10.0; the plugin resolves all three at runtime.
    bun run --cwd packages/ast-grep-mcp build
    bun run --cwd packages/git-bash-mcp build

    # Build the lsp_tools MCP server (npm-managed submodule) offline
    # against the pre-fetched npm cache
    pushd packages/lsp-tools-mcp >/dev/null
      export HOME="$TMPDIR"
      export npm_config_cache="$TMPDIR/npm-cache"
      cp -r --no-preserve=mode ${lspToolsMcpDeps} "$npm_config_cache"
      npm ci --offline --no-audit --no-fund --ignore-scripts
      # /usr/bin/env shebangs in npm-installed bins (tsc, ...) fail in the sandbox
      patchShebangs node_modules
      npm run build
    popd >/dev/null

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/oh-my-opencode $out/bin

    cp -r dist node_modules package.json $out/lib/oh-my-opencode/

    # The plugin resolves its MCP servers at
    # <ancestor>/packages/{ast-grep-mcp,git-bash-mcp,lsp-tools-mcp}/dist/cli.js
    mkdir -p $out/lib/oh-my-opencode/packages
    cp -r packages/{ast-grep-mcp,git-bash-mcp,lsp-tools-mcp,shared-skills} $out/lib/oh-my-opencode/packages/

    # ast-grep-mcp's and git-bash-mcp's dist/cli.js are self-contained bun
    # bundles; their node_modules only hold workspace symlinks that would
    # dangle in $out and fail noBrokenSymlinks. lsp-tools-mcp keeps its
    # node_modules — tsc output imports deps at runtime.
    rm -rf $out/lib/oh-my-opencode/packages/ast-grep-mcp/node_modules
    rm -rf $out/lib/oh-my-opencode/packages/git-bash-mcp/node_modules

    # Remove broken workspace symlinks (monorepo workspace packages
    # aren't needed at runtime — the CLI bundle is self-contained)
    find $out/lib/oh-my-opencode/node_modules/@oh-my-opencode -xtype l -delete 2>/dev/null || true
    rmdir $out/lib/oh-my-opencode/node_modules/@oh-my-opencode 2>/dev/null || true

    makeWrapper ${bun}/bin/bun $out/bin/oh-my-opencode \
      --add-flags "run $out/lib/oh-my-opencode/dist/cli/index.js"

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "The Best AI Agent Harness - Multi-Model Orchestration for OpenCode";
    homepage = "https://github.com/code-yeongyu/oh-my-openagent";
    changelog = "https://github.com/code-yeongyu/oh-my-openagent/releases/tag/v${version}";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ titaniumtown ];
    mainProgram = "oh-my-opencode";
    platforms = platforms.unix;
  };
}
