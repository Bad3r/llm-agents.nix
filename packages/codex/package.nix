{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  rustPlatform,
  pkg-config,
  lld,
  cmake,
  alsa-lib,
  gst_all_1,
  aws-lc,
  openssl,
  oniguruma,
  rust-bindgen,
  sqlite,
  zstd,
  bubblewrap,
  ripgrep,
  libcap,
  versionCheckHook,
  callPackage,
  mkRustyV8Archive ? callPackage ../../lib/rusty-v8.nix { },
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
  version ? versionData.version,
  hash ? versionData.hash,
  # Named srcOverride because a `src` argument would be autofilled by
  # callPackage from the throwing `pkgs.src` alias.
  srcOverride ? null,
  sourceRoot ? "source/codex-rs",
  cargoVendor ? {
    cargoHash = versionData.cargoHash;
  },
  preBuild ? ''
    # Upstream's ThinLTO + codegen-units=4 make late-stage rustc peak at
    # ~12 GiB and the whole build crawl; fall back to cargo defaults like
    # nixpkgs does. Line tables for codex-core/codex-tui add more memory
    # and the aarch64 builders OOM-kill rustc when many big crates compile
    # in parallel, so drop debuginfo and cap cargo's job count.
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "thin"' "" \
      --replace-fail 'codegen-units = 4' "" \
      --replace-fail 'debug = "line-tables-only"' 'debug = "none"'
    if [ "$NIX_BUILD_CORES" -gt 8 ]; then
      export NIX_BUILD_CORES=8
    fi
  '',
  doInstallCheck ? true,
  librusty_v8 ? mkRustyV8Archive versionData.librusty_v8,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
  # JavaScript code mode, run by codex-code-mode-host on a prebuilt V8.
  withCodeMode ? true,
  # Realtime voice through codex-voice-host and GStreamer.
  withVoice ? false,
}:

assert lib.assertMsg (
  withVoice -> stdenv.hostPlatform.isLinux
) "codex: withVoice supports only Linux";

let
  actualSrc =
    if srcOverride != null then
      srcOverride
    else
      fetchFromGitHub {
        owner = "openai";
        repo = "codex";
        tag = "rust-v${version}";
        inherit hash;
      };

  packageManifest = builtins.toJSON {
    layoutVersion = 1;
    inherit version;
    target = stdenv.hostPlatform.rust.rustcTarget;
    variant = "codex";
    entrypoint = "bin/codex";
    resourcesDir = "codex-resources";
    pathDir = "codex-path";
  };

  # Plugins codex-voice-host loads by path (voice-host/src/runtime.rs).
  voicePlugins = {
    coreelements = gst_all_1.gstreamer.out;
    app = gst_all_1.gst-plugins-base;
    audioconvert = gst_all_1.gst-plugins-base;
    audioresample = gst_all_1.gst-plugins-base;
    opus = gst_all_1.gst-plugins-base;
    rtp = gst_all_1.gst-plugins-good;
    rtpmanager = gst_all_1.gst-plugins-good;
  };

in
rustPlatform.buildRustPackage (
  {
    pname = "codex";
    inherit version sourceRoot;
    src = actualSrc;

    cargoBuildFlags = [
      "--package"
      "codex-cli"
    ]
    ++ lib.optionals withCodeMode [
      "--package"
      "codex-code-mode-host"
    ]
    ++ lib.optionals withVoice [
      "--package"
      "codex-voice-host"
    ];

    nativeBuildInputs = [
      installShellFiles
      pkg-config
      rust-bindgen
    ]
    # opusic-sys builds its bundled libopus with cmake.
    ++ lib.optionals withVoice [ cmake ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      # Unable to find libclang: "couldn't find any valid shared libraries matching: ['libclang.dylib']
      rustPlatform.bindgenHook
    ];

    buildInputs = [
      aws-lc
      openssl
      oniguruma
      sqlite
      zstd
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ libcap ]
    ++ lib.optionals withVoice [
      alsa-lib
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ];

    dontUseCmakeConfigure = true;

    env = {
      AWS_LC_SYS_USE_SYSTEM = "1";
      LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
      RUSTONIG_SYSTEM_LIBONIG = "1";
      ZSTD_SYS_USE_PKG_CONFIG = "1";
    }
    // lib.optionalAttrs withCodeMode {
      RUSTY_V8_ARCHIVE = librusty_v8;
    }
    // lib.optionalAttrs (withCodeMode && librusty_v8 ? srcBinding) {
      # rusty_v8 >= 150 include!s this instead of running bindgen.
      RUSTY_V8_SRC_BINDING_PATH = librusty_v8.srcBinding;
    }
    // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
      # nixpkgs' ld64 fails to insert ARM64 branch thunks for this binary
      # (`b(l) ARM64 branch out of range`, #4417); lld handles it.
      NIX_CFLAGS_LINK = "-fuse-ld=${lib.getExe' lld "ld64.lld"}";
    };

    # The daemon would copy the whole package (~550 MB) into ~/.codex and let
    # upstream's updater replace it. Run it from the store instead.
    # Upstream skips symlinked rules files, which drops Home Manager links.
    patches = [
      ./daemon-nix-store.patch
      ./rules-symlink.patch
      ./ui-theme.patch
      ./web-run-command.patch
    ]
    # The voice runtime only accepts physical files; resolve store symlinks.
    ++ lib.optional withVoice ./voice-runtime-symlinks.patch;

    # webpki-roots 1.0.10 drops the emSign roots and rustls-webpki 0.103.16
    # rejects the revoked eMudhra intermediates. Upstream main has both;
    # drop this once a release ships them.
    cargoPatches = lib.optional (lib.versionOlder version "0.164.0") ./webpki-bump.patch;

    # The future returned by `connectors::list_connectors` nests deeply
    # enough that computing its layout exceeds rustc's default query depth
    # limit of 128 ("queries overflow the depth limit"). Raise the limit for
    # this crate, as rustc's diagnostic suggests and as upstream already does
    # for app-server, exec and tui.
    postPatch = ''
      substituteInPlace app-server-daemon/src/prepare_install.rs \
        --subst-var-by storeDir ${builtins.storeDir} \
        --subst-var out
      if ! grep -q 'recursion_limit' chatgpt/src/lib.rs; then
        substituteInPlace chatgpt/src/lib.rs \
          --replace-fail 'pub mod apply_command;' \
          $'#![recursion_limit = "256"]\n\npub mod apply_command;'
      fi
    '';

    inherit preBuild;

    # The daemon refuses to start unless it finds upstream's package layout
    # around its executable (#9887).
    postFixup = ''
      mkdir -p $out/libexec/codex/{bin,codex-path,codex-resources}
      mv $out/bin/codex $out/bin/logs_client $out/libexec/codex/bin/
      ${
        if withCodeMode then
          ''
            mv $out/bin/codex-code-mode-host $out/libexec/codex/bin/
            ln -s ../libexec/codex/bin/codex-code-mode-host $out/bin/codex-code-mode-host
          ''
        else
          ''
            # The daemon refuses a package without this file.
            printf '#!/bin/sh\necho "codex was built without code mode" >&2\nexit 1\n' \
              > $out/libexec/codex/bin/codex-code-mode-host
            chmod +x $out/libexec/codex/bin/codex-code-mode-host
          ''
      }
      ${lib.optionalString withVoice ''
        voice=$out/libexec/codex/codex-resources/voice
        mkdir -p $voice/bin $voice/lib/gstreamer-1.0
        mv $out/bin/codex-voice-host $voice/bin/
        ln -s ${lib.getLib gst_all_1.gstreamer}/lib/libgstreamer-1.0.so.0 $voice/lib/
        ${lib.concatMapAttrsStringSep "" (name: pkg: ''
          ln -s ${lib.getLib pkg}/lib/gstreamer-1.0/libgst${name}.so $voice/lib/gstreamer-1.0/
        '') voicePlugins}
      ''}
      ln -s ${lib.getExe ripgrep} $out/libexec/codex/codex-path/rg
      printf '%s\n' ${lib.escapeShellArg packageManifest} \
        > $out/libexec/codex/codex-package.json

      ${lib.optionalString stdenv.hostPlatform.isLinux ''
        ln -s ${lib.getExe bubblewrap} $out/libexec/codex/codex-resources/bwrap
      ''}
      ln -s ../libexec/codex/bin/codex $out/bin/codex
      ln -s ../libexec/codex/bin/logs_client $out/bin/logs_client
    '';

    doCheck = false;

    postInstall = lib.optionalString installShellCompletions ''
      installShellCompletion --cmd codex \
        --bash <($out/bin/codex completion bash) \
        --fish <($out/bin/codex completion fish) \
        --zsh <($out/bin/codex completion zsh)
    '';

    inherit doInstallCheck;
    nativeInstallCheckInputs = [ versionCheckHook ];

    passthru = {
      category = "AI Coding Agents";
      inherit mkRustyV8Archive;
      inherit librusty_v8;
    };

    meta = {
      description = "OpenAI Codex CLI - a coding agent that runs locally on your computer";
      homepage = "https://github.com/openai/codex";
      changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
      sourceProvenance = [
        lib.sourceTypes.fromSource
      ]
      ++ lib.optional withCodeMode lib.sourceTypes.binaryNativeCode; # librusty_v8
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = lib.platforms.unix;
    };
  }
  // cargoVendor
)
