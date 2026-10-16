{
  lib,
  buildNpmPackage,
  fetchzip,
  mkUpdater,
  nodejs_24,
  postgresql_18,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
  writeText,
  flake,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;

  src = runCommand "paperclipai-${version}-src" { } ''
    mkdir -p $out
    cp -r ${
      fetchzip {
        url = "https://registry.npmjs.org/paperclipai/-/paperclipai-${version}.tgz";
        inherit hash;
      }
    }/. $out/
    cp ${./package-lock.json} $out/package-lock.json
  '';

  binaryJs = writeText "binary.js" ''
    function getBinaries() {
      return Promise.resolve({
        postgres: "${postgresql_18}/bin/postgres",
        initdb: "${postgresql_18}/bin/initdb",
        pg_ctl: "${postgresql_18}/bin/pg_ctl",
      });
    }
    export default getBinaries;
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "paperclip";
  inherit version src npmDepsHash;

  nodejs = nodejs_24;
  makeCacheWritable = true;

  # The npm tarball is already built.
  dontNpmBuild = true;

  # Skip postinstall scripts of bundled platform packages.
  npmFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  # Replace the embedded PostgreSQL with the one from nixpkgs. paperclipai
  # bundles more than one copy of embedded-postgres; patch every one, since
  # the platform binaries any unpatched copy imports are removed below.
  postInstall = ''
    binaries=$(find $out/lib/node_modules -path '*/embedded-postgres/dist/binary.js')
    test -n "$binaries"
    while IFS= read -r embedded; do
      install -m644 ${binaryJs} "$embedded"

      # nixpkgs PostgreSQL defaults its unix socket to /run/postgresql, which
      # unprivileged users cannot write to. Keep the socket in the data dir.
      substituteInPlace "$(dirname "$embedded")/index.js" \
        --replace-fail "...this.options.postgresFlags," \
          "'-k', this.options.databaseDir, ...this.options.postgresFlags,"
    done <<<"$binaries"

    # Drop the now unused FHS-linked binaries.
    find $out/lib/node_modules -path '*/node_modules/@embedded-postgres/*' -prune \
      ! -name symlink-reader -exec rm -rf {} +
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Assistants";
  passthru.updater = mkUpdater {
    kind = "npm";
    purl = "pkg:npm/paperclipai";
    fetchzip = true;
    supplementOptionalDeps = true;
  };

  meta = {
    description = "Open-source control plane for managing teams of AI agents";
    homepage = "https://paperclip.ing";
    changelog = "https://github.com/paperclipai/paperclip/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/paperclipai";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "paperclipai";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
