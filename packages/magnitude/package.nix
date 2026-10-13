{
  lib,
  flake,
  stdenv,
  fetchurl,
  dpkg,
  jq,
  formatelf,
  wrapBuddy,
  makeWrapper,
  addDriverRunpath,
  versionCheckHook,
  versionCheckHomeHook,

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
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,

  # libs-only build of systemd to avoid pulling the whole systemd closure
  systemdLibs,

  libglvnd,
  libsecret,
  libnotify,
  libpulseaudio,
  libayatana-appindicator,
  libXcursor,
  pipewire,
  util-linux,
  vulkan-loader,
  wayland,
  xdg-utils,

  # Needed for XDG_ICON_DIRS and GSETTINGS_SCHEMAS_PATH.
  adwaita-icon-theme,
  gsettings-desktop-schemas,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version revision;
  inherit (stdenv.hostPlatform) system;

  # Release manifest host and Debian architecture per nix system.
  platforms = {
    x86_64-linux = {
      host = "linux-x64-gnu";
      debArch = "amd64";
    };
    aarch64-linux = {
      host = "linux-arm64-gnu";
      debArch = "arm64";
    };
  };
  platform = platforms.${system} or (throw "Unsupported system: ${system}");

  releaseUrl = "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev/cli%40${version}";

  desktopSrc = fetchurl {
    url = "${releaseUrl}/magnitude-desktop_${version}-${toString revision}_${platform.debArch}.deb";
    hash = versionData.desktop.${system};
  };

  # Upstream's service downloads this engine into ~/.magnitude on first start
  # unless MAGNITUDE_ICN_PATH names an installation declaration.
  inferenceSrc = fetchurl {
    url = "${releaseUrl}/magnitude-icn-base-${platform.host}.tar.gz";
    hash = versionData.inference.${system};
  };
in
stdenv.mkDerivation {
  pname = "magnitude";
  inherit version;

  srcs = [
    desktopSrc
    inferenceSrc
  ];

  nativeBuildInputs = [
    dpkg
    jq
    formatelf
    wrapBuddy
    makeWrapper
  ];

  buildInputs = [
    adwaita-icon-theme
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
    gsettings-desktop-schemas
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

  # dlopen()ed at runtime, so not discoverable from DT_NEEDED: libsecret by
  # the service, vulkan-loader by the engine, the rest by Electron.
  runtimeDependencies = [
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    libXcursor
    pipewire
    vulkan-loader
    wayland
  ];

  # The engine dlopen()s libcuda.so.1 with LD_LIBRARY_PATH cleared by the
  # service, so the driver directory has to be on its RUNPATH.
  appendRunpaths = [ "${addDriverRunpath.driverLink}/lib" ];

  # dpkg -x preserves modes and fails on the setuid-root chrome-sandbox.
  unpackPhase = ''
    runHook preUnpack
    mkdir desktop inference
    dpkg-deb --fsys-tarfile ${desktopSrc} | tar -x --no-same-permissions --no-same-owner -C desktop
    tar -xzf ${inferenceSrc} -C inference
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # The CLI only accepts an install root where it runs as
    # resources/magnitude, next to magnitude-service and desktop-host.node.
    mkdir -p $out/bin $out/lib $out/share
    cp -a desktop/usr/lib/magnitude-desktop $out/lib/magnitude-desktop
    cp -a desktop/usr/share/{applications,icons} $out/share/
    cp -a inference $out/lib/magnitude-inference

    # chrome-sandbox needs setuid root, which a store path can never have.
    rm $out/lib/magnitude-desktop/chrome-sandbox
    # Without these the app and `magnitude serve` report updates as
    # unavailable instead of downloading debs they cannot install.
    rm $out/lib/magnitude-desktop/resources/update-{configuration,package,trust}.json

    # desktop-host.node refuses `magnitude serve` and the app unless a
    # root-owned, mode 0444 /var/lib/magnitude-desktop/installation.lock
    # exists; the deb's preinst creates it, so the system has to provide it.
    makeWrapper $out/lib/magnitude-desktop/resources/magnitude $out/bin/magnitude \
      --set-default MAGNITUDE_ICN_PATH $out/lib/magnitude-inference/installation.json

    # The app exits 1 unless it inherits launch's shared flock on that lock as fd 9.
    substituteInPlace $out/lib/magnitude-desktop/launch \
      --replace-fail /usr/lib/magnitude-desktop/magnitude $out/lib/magnitude-desktop/magnitude \
      --replace-fail 'flock -s' '${lib.getExe' util-linux "flock"} -s'
    makeWrapper $out/lib/magnitude-desktop/launch $out/bin/magnitude-desktop \
      --set-default MAGNITUDE_ICN_PATH $out/lib/magnitude-inference/installation.json \
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd ]}" \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  # Only the engine carries DWARF (about 800 MB); stripping the bun-compiled
  # CLI and service corrupts their embedded payload.
  stripDebugList = [ "lib/magnitude-inference" ];

  # formatelf would rewrite the bun binaries, which only survive wrapBuddy.
  dontAutoPatchelf = true;
  dontWrapBuddy = true;
  postFixup = ''
    wrapBuddy -- $out/lib/magnitude-desktop/resources/{magnitude,magnitude-service}
    autoPatchelf -- \
      $(find $out/lib/magnitude-desktop -mindepth 1 -maxdepth 1 ! -name resources) \
      $out/lib/magnitude-desktop/resources/{desktop-host.node,magnitude-command} \
      $out/lib/magnitude-inference
    # autoPatchelf replaces the RUNPATH entry the engine dlopen()s NVRTC through.
    formatelf --add-rpath '$ORIGIN/../runtime' $out/lib/magnitude-inference/bin/magnitude-inference

    # Same declaration upstream writes after probing a downloaded engine.
    nativeBuild=$($out/lib/magnitude-inference/bin/magnitude-inference version --json | jq -er .native_build)
    jq -n --arg nativeBuild "$nativeBuild" '{schemaVersion: 1, nativeBuild: $nativeBuild}' \
      > $out/lib/magnitude-inference/installation.json
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  # The sandbox has no installation.lock, so the launch gate must refuse with 75.
  postInstallCheck = ''
    if [ ! -e /var/lib/magnitude-desktop/installation.lock ]; then
      status=0
      $out/bin/magnitude-desktop 2>launch.err || status=$?
      test "$status" -eq 75
      grep -q 'package-manager repair' launch.err
    fi
  '';

  passthru = {
    category = "Utilities";
    sources = {
      desktop = desktopSrc;
      inference = inferenceSrc;
    };
  };

  meta = {
    description = "Local inference engine for agents that tunes its kernels to the host hardware";
    homepage = "https://magnitude.dev";
    changelog = "https://github.com/magnitudedev/magnitude/releases/tag/%40magnitudedev%2Fcli%40${version}";
    # The engine bundles NVIDIA NVRTC under the CUDA EULA.
    license = [
      lib.licenses.asl20
      flake.lib.licenses.unfree
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ Bad3r ];
    mainProgram = "magnitude";
    platforms = lib.attrNames platforms;
  };
}
