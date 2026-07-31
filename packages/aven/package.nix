{
  lib,
  fetchFromGitHub,
  rustPlatform,
  cacert,
  git,
  sqlite,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "aven";
  version = "0.1.19";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "aven";
    tag = "v${finalAttrs.version}";
    hash = "sha256-O061QVxle2f9UdGBNdgovBskpT1tpUiEqAVHbyChDtI=";
  };

  cargoHash = "sha256-fDM1ymMOmCUc7q7onb5Fn49frzXtmZO4hk9ESgbCBww=";

  # Some tests infer the project key from the checkout directory name
  # ("aven" -> "AVN"), but Nix unpacks into "source".
  postUnpack = ''
    mv source aven
    export sourceRoot=aven
  '';

  # Only build the CLI crate, not the aven-uniffi mobile bindings.
  cargoBuildFlags = [
    "--package"
    "aven"
  ];

  postInstall = ''
    install -d $out/share/aven
    cp -r skills $out/share/aven/skills
  '';

  # git: tests infer the project from the checkout's git repo (see preCheck).
  # sqlite: attachment tests shell out to `sqlite3`.
  # cacert: rustls-native-certs fails without system CA certs in the sandbox.
  nativeCheckInputs = [
    cacert
    git
    sqlite
  ];

  checkFlags = [
    # Needs a system zoneinfo database, which the sandbox lacks
    # (chrono ignores $TZDIR: https://github.com/chronotope/chrono/issues/1265).
    "--skip=local_calendar_dates_use_offsets_across_daylight_saving_boundaries"
    # `aven backup` races its own WAL connection against a `sqlite3 .backup`
    # subprocess and flakes as "database is locked" on loaded runners.
    "--test-threads=1"
  ];

  # Many tests rely on inferring the project from the surrounding git repo;
  # the sandbox is not a git repo, so create one.
  preCheck = ''
    export HOME=$(mktemp -d)
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    git init -q .
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Local-first task manager for power users and agents";
    homepage = "https://github.com/raine/aven";
    changelog = "https://github.com/raine/aven/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "aven";
    maintainers = with lib.maintainers; [ sei40kr ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
  };
})
