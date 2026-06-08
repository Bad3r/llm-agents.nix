{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  git,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "claw-code";
  version = "0-unstable-2026-06-07";

  src = fetchFromGitHub {
    owner = "ultraworkers";
    repo = "claw-code";
    rev = "ae2f203eb5462fbb75f7e719da465c32fcd8b979";
    hash = "sha256-OHfotPqCzUX1Im8sv7zQ3WrLWPwPv8ke+/fkLRwYLFI=";
  };

  sourceRoot = "source/rust";

  # Upstream merge commit ae2f203 botched the conflict resolution in
  # crates/api/src/providers/openai_compat.rs, leaving a duplicated tail of
  # send_message behind the closing brace, which fails to parse. Drop the
  # stray block until upstream fixes it.
  # Reported upstream: https://github.com/ultraworkers/claw-code/issues/3235
  patches = [ ./fix-openai-compat-bad-merge.patch ];

  # Upstream added a criterion dev-dependency to crates/api without
  # regenerating Cargo.lock, so cargo can't resolve it from the vendored
  # set. We don't run that crate's benches, so just drop the dep.
  postPatch = ''
    sed -i '/^criterion = /d' crates/api/Cargo.toml
  '';

  cargoHash = "sha256-Acaycrxm3e87dx3P7NdWnivopF4xxaMi3PPbpSefEyY=";

  cargoBuildFlags = [
    "--package"
    "rusty-claude-cli"
  ];
  cargoTestFlags = cargoBuildFlags;

  # Upstream's #[cfg(test)] block in rusty-claude-cli/src/main.rs is broken
  # at this rev (ApiError::Api initializers missing the new suggested_action
  # field). The release binary compiles fine, so skip cargo test until
  # upstream catches up.
  doCheck = false;

  nativeCheckInputs = [ git ];

  preCheck = ''
    export HOME=$TMPDIR
  '';

  checkFlags = [
    # broken upstream at this rev: tool allow-list assertions out of sync with implementation
    "--skip=tests::rejects_unknown_allowed_tools"
    "--skip=tests::build_runtime_plugin_state_discovers_mcp_tools_and_surfaces_pending_servers"
    # integration harness expects scripted plugin fixtures not present in sandbox
    "--skip=clean_env_cli_reaches_mock_anthropic_service_across_scripted_parity_scenarios"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  # Upstream has no tagged release yet; we track an unstable rev. The binary
  # reports the Cargo workspace.package.version (e.g. 0.1.0), so compare
  # against that rather than our `0-unstable-<date>` derivation version.
  preVersionCheck = ''
    version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Claude Code rewrite CLI built from the official claw-code Rust workspace";
    homepage = "https://github.com/ultraworkers/claw-code";
    changelog = "https://github.com/ultraworkers/claw-code/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "claw";
    platforms = lib.platforms.unix;
  };
}
