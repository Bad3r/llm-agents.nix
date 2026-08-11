{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
  postgresql_18,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
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

  # Replace the embedded PostgreSQL with the one from nixpkgs.
  postInstall = ''
        embedded=$(find $out/lib/node_modules -path '*/embedded-postgres/dist/binary.js' -print -quit)
        test -n "$embedded"
        cat > "$embedded" <<'EOF'
    function getBinaries() {
      return Promise.resolve({
        postgres: "${postgresql_18}/bin/postgres",
        initdb: "${postgresql_18}/bin/initdb",
        pg_ctl: "${postgresql_18}/bin/pg_ctl",
      });
    }
    export default getBinaries;
    EOF

        # nixpkgs PostgreSQL defaults its unix socket to /run/postgresql, which
        # unprivileged users cannot write to. Keep the socket in the data dir.
        substituteInPlace "$(dirname "$embedded")/index.js" \
          --replace-fail "...this.options.postgresFlags," \
            "'-k', this.options.databaseDir, ...this.options.postgresFlags,"

        # Drop the now unused FHS-linked binaries.
        while IFS= read -r scope; do
          find "$scope" -mindepth 1 -maxdepth 1 ! -name symlink-reader -exec rm -rf {} +
        done < <(find $out/lib/node_modules -path '*/node_modules/@embedded-postgres' -type d)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Assistants";

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
