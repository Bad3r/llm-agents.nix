{
  lib,
  stdenv,
  platformSource,
  mkUpdater,
  makeWrapper,
  formatelf,
  libarchive,
  versionCheckHook,
  codesignCheckHook,

  # DT_NEEDED by the bundled Electron and the pixel.node engine.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  gtk3,
  libgbm,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,

  # dlopen()ed by Chromium at runtime.
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  pipewire,
  wayland,
}:

let
  electronBinary =
    if stdenv.hostPlatform.isDarwin then
      "electron/terminal-browser.app/Contents/MacOS/terminal-browser"
    else
      "electron/pixel";
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://github.com/zenbu-labs/terminal-browser/releases/download/v{version}/terminal-browser-{platform}.tar.gz";
  };
in
stdenv.mkDerivation {
  pname = "terminal-browser";
  inherit (source) version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ libarchive ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ formatelf ];

  # The darwin tarball carries macOS metadata as AppleDouble `._*` members.
  # GNU tar does not recognise them and writes them out as ordinary files
  # inside the signed app bundle, where codesign sees files the signature does
  # not cover: `file added: .../Resources/id_FEMININE.lproj/._locale.pak`, and
  # so "a sealed resource is missing or invalid" for Electron
  # Framework.framework. macOS then refuses to launch the app as damaged.
  # bsdtar consumes the metadata instead of materialising it.
  unpackCmd = lib.optionalString stdenv.hostPlatform.isDarwin ''
    bsdtar -xf "$curSrc"
  '';

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    gtk3
    libgbm
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
  ];

  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    pipewire
    wayland
  ];

  # The bundled Electron is a zenbu-labs fork with terminal rendering
  # patches, so it cannot be swapped for nixpkgs' electron. The CLI locates
  # everything under TERMINAL_BROWSER_DIST_ROOT, so the upstream tree stays
  # intact. Upstream's bin/terminal-browser launcher needs coreutils on PATH,
  # so it is replaced by a symlink to the wrapper. `open --split` execs that
  # path in the new pane.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -a . $out/lib/terminal-browser
    ln -sf $out/bin/terminal-browser $out/lib/terminal-browser/bin/terminal-browser
    makeWrapper "$out/lib/terminal-browser/${electronBinary}" $out/bin/terminal-browser \
      --set TERMINAL_BROWSER_DIST_ROOT "$out/lib/terminal-browser" \
      --set ELECTRON_RUN_AS_NODE 1 \
      ${lib.optionalString stdenv.hostPlatform.isDarwin ''--set-default NATIVE_SCROLL_HELPER "$out/lib/terminal-browser/bin/native-scroll-helper"''} \
      --add-flags "$out/lib/terminal-browser/cli/dist/main.js"
    runHook postInstall
  '';

  dontStrip = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    codesignCheckHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ versionCheckHook ];
  codesignTeamId = "7YBC6H852Y";
  codesignSources = source.darwinSrcs;
  versionCheckProgramArg = "--version";

  passthru.category = "Utilities";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "zenbu-labs";
        repo = "terminal-browser";
      };
    }
  );

  meta = {
    description = "Browser that runs inside your terminal, with a CLI for agents";
    homepage = "https://terminal-browser.com/";
    changelog = "https://github.com/zenbu-labs/terminal-browser/releases/tag/v${source.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ zimbatm ];
    mainProgram = "terminal-browser";
    platforms = source.platforms;
  };
}
