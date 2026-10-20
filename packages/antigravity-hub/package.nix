{
  lib,
  flake,
  stdenv,
  fetchurl,
  alsa-lib,
  asar,
  at-spi2-atk,
  at-spi2-core,
  atk,
  formatelf,
  cairo,
  copyDesktopItems,
  cups,
  dbus,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeDesktopItem,
  makeShellWrapper,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  unzip,
  wrapGAppsHook3,
  mkUpdater,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  # Upstream release ids are "<version>-<buildId>".
  release = versionData.version;
  platforms = {
    x86_64-linux = "linux-x64/Antigravity.tar.gz";
    aarch64-linux = "linux-arm/Antigravity.tar.gz";
    aarch64-darwin = "darwin-arm/Antigravity.zip";
  };
  system = stdenv.hostPlatform.system;
in
stdenv.mkDerivation {
  pname = "antigravity-hub";
  version = lib.head (lib.splitString "-" release);

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${release}/${
      platforms.${system} or (throw "Unsupported system: ${system}")
    }";
    hash = versionData.hashes.${system};
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      asar
      formatelf
      copyDesktopItems
      makeShellWrapper
      wrapGAppsHook3
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ unzip ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gsettings-desktop-schemas
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemd
  ];

  # Loaded with dlopen().
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux (
    map lib.getLib [
      libnotify
      libpulseaudio
      libsecret
      pipewire
    ]
  );

  # The bundled ANGLE libraries dlopen() libGL; runtimeDependencies only
  # patches executables.
  appendRunpaths = lib.optionals stdenv.hostPlatform.isLinux [ "${lib.getLib libGL}/lib" ];

  dontWrapGApps = true;

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "antigravity-hub";
      desktopName = "Antigravity";
      comment = "Manage multiple autonomous agents across independent projects";
      exec = "antigravity %U";
      icon = "antigravity";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/antigravity" ];
      startupWMClass = "Antigravity";
    })
  ];

  installPhase =
    if stdenv.hostPlatform.isDarwin then
      ''
        runHook preInstall

        mkdir -p $out/Applications/Antigravity.app $out/bin
        cp -R . $out/Applications/Antigravity.app
        ln -s $out/Applications/Antigravity.app/Contents/MacOS/Antigravity $out/bin/antigravity

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/share/antigravity
        cp -r . $out/share/antigravity

        asar extract-file resources/app.asar icon.png
        install -Dm644 icon.png $out/share/icons/hicolor/512x512/apps/antigravity.png

        runHook postInstall
      '';

  # Keep the code signature intact.
  dontFixup = stdenv.hostPlatform.isDarwin;

  # makeShellWrapper, because --add-flags expands shell variables.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    makeShellWrapper $out/share/antigravity/antigravity $out/bin/antigravity \
      "''${gappsWrapperArgs[@]}"
  '';

  passthru = {
    category = "AI Assistants";
    updater = mkUpdater {
      kind = "platform";
      versionSource = {
        type = "text";
        url = "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/latest-x64-linux.yml";
        regex = "/antigravity-hub/([0-9.]+-[0-9]+)/";
      };
      urlTemplate = "https://storage.googleapis.com/antigravity-public/antigravity-hub/{version}/{platform}";
      inherit platforms;
    };
  };

  meta = with lib; {
    description = "Desktop environment for managing multiple autonomous agents across independent projects";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    downloadPage = "https://antigravity.google/download";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames platforms;
    mainProgram = "antigravity";
    maintainers = with maintainers; [
      sinics
    ];
  };
}
