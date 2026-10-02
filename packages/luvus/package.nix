{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  pkg-config,
  curl,
  git,
  python3,
  gh,
  openssh,
  bashInteractive,
  coreutils,
  procps,
  sqlite,
  tzdata,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  runtimeTools = [
    git
    gh
    openssh
    bashInteractive
    coreutils
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    procps
  ];
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "luvus";
  version = "0.14.3";

  src = fetchFromGitHub {
    owner = "RizRiyz";
    repo = "luvus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Y1OC+LJhU+hJJ4q1wuFHXpV7hbVtvtfJITegtwAevUQ=";
  };

  cargoHash = "sha256-Aps3N1GaEgr70xr4IkXXe8Tb8h1RmaIphwrqGBj8Enk=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [ sqlite ];

  env.LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";

  # needs git worktrees and curl for a file:// fetch
  nativeCheckInputs = [
    curl
    git
    # the fake worktree provider in the tests parses its request with python
    python3
  ];

  # flaky: spawn real PTYs/processes and race under load
  checkFlags = [
    "--test-threads=1"
    "--skip=app::tests::clicking_a_pane_title_shows_the_real_command"
    "--skip=app::tests::keyboard_copy_mode_yanks_history_and_cancel_restores_its_viewport"
    "--skip=app::tests::keyboard_copy_word_navigation_uses_visual_columns"
    "--skip=app::files::tests::previewing_from_a_dashboard_tab_opens_a_tab_and_still_reuses_it"
    "--skip=app::tests::resize_yields_to_pane_title_and_zoom_but_still_grabs_the_seam"
    "--skip=app::tests::resume_session_opens_pane"
    "--skip=platform::tests::process_tree_finds_this_process_and_its_children"
    "--skip=app::settings::tests::enter_routes_an_installed_theme_through_removal"
    # opens the git dashboard on the build dir, which is not a repository
    "--skip=app::diff::tests::dashboard_diff_click_opens_a_tab_then_reuses_it"
    "--skip=app::input::tests::a_key_that_dismisses_the_bar_overflow_never_repeats_into_the_view"
    # runs /usr/bin/env, which does not exist in the sandbox
    "--skip=orch::worker::tests::direct_launch_delivers_a_multiline_briefing_beyond_canonical_tty_limits"
    "--skip=integration::tests::hook_script_reports_claude_but_never_a_devin_host"
    # the pane's real shell prints its `bash-5.3$ ` prompt into the screen the
    # tests fill, shifting the expected match columns and counts
    "--skip=app::input::tests::pane_search_word_highlight_does_not_use_global_flash"
    "--skip=app::search::tests::legacy_exact_search_uses_shared_folding_and_original_byte_columns"
    # copies /bin/sleep, which does not exist in the sandbox
    "--skip=platform::tests::unix_stoppable_pid_accepts_a_luvus_executable_with_arguments"
    # the reopened App does not read the persisted toggle back in the sandbox
    "--skip=app::files::tests::files_show_hidden_defaults_on_and_the_setting_persists"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # process table is restricted in the darwin sandbox
    "--skip=platform::tests::pane_runtime_scan_projects_cwd_and_commands_from_one_snapshot"
  ];

  # Many tests spawn a "home terminal" in $HOME. Config lives in $LUVUS_HOME,
  # pointed elsewhere so tests persisting config do not race on a shared default.
  # jiff reads the system zoneinfo (no bundled tzdb on unix).
  preCheck = ''
    export HOME=$(mktemp -d)
    export LUVUS_HOME=$(mktemp -d)
    export TZDIR=${tzdata}/share/zoneinfo
  '';

  postFixup = ''
    wrapProgram $out/bin/luvus \
      --prefix PATH : ${lib.makeBinPath runtimeTools} \
      --set-default TZDIR ${tzdata}/share/zoneinfo
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Mission control for your AI coding agents";
    homepage = "https://luvus.dev";
    changelog = "https://github.com/RizRiyz/luvus/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with flake.lib.maintainers; [ r17x ];
    mainProgram = "luvus";
    platforms = lib.platforms.unix;
  };
})
