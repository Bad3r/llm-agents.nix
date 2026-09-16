{
  lib,
  stdenv,
  stdenvNoCC,
  platformSource,
  formatelf,
  leptonica,
  libxkbcommon,
  pipewire,
  tesseract5,
  versionCheckHook,
  codesignCheckHook,
  mkUpdater,
}:

let
  # Upstream publishes signed, notarized release binaries for every supported
  # platform. Building from source would need a Swift toolchain (the macOS
  # driver bridges to Swift), cmake for the vendored MediaRemoteAdapter
  # framework, and the tesseract/leptonica development headers.
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      aarch64-darwin = "aarch64-apple-darwin";
    };
    urlTemplate = "https://github.com/moeru-ai/auv/releases/download/v{version}/auv-{platform}.tar.gz";
  };

  # The Linux release binaries are built on Ubuntu 24.04 against leptonica 1.82,
  # whose soname is `liblept.so.5`. nixpkgs ships leptonica 1.87, which renamed
  # the library and bumped the soname to `libleptonica.so.6`. The only leptonica
  # entry points the binary imports (`pixClone`, `pixDestroy`, `pixReadMem`) are
  # unchanged, so a soname alias is enough for the dynamic loader.
  leptonicaSonameAlias = stdenvNoCC.mkDerivation {
    pname = "leptonica-liblept-soname-alias";
    inherit (leptonica) version;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      ln -s ${lib.getLib leptonica}/lib/libleptonica.so.6 $out/lib/liblept.so.5
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "auv";
  inherit (source) version src;

  sourceRoot = ".";

  # `auto-formatelf` rewrites the ELF interpreter and resolves the DT_NEEDED
  # libraries below from buildInputs.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ formatelf ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    leptonica
    leptonicaSonameAlias
    libxkbcommon
    pipewire
    tesseract5
    stdenv.cc.cc.lib
  ];

  # The macOS payload is Developer ID-signed with the hardened runtime;
  # stripping it would invalidate the code signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 auv $out/bin/auv

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    codesignCheckHook
  ];
  codesignTeamId = "433DLLA855";
  codesignSources = source.darwinSrcs;

  passthru.category = "Utilities";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "moeru-ai";
        repo = "auv";
      };
    }
  );

  meta = with lib; {
    description = "Scriptable computer-use automation CLI that turns GUI operations into reusable commands";
    homepage = "https://github.com/moeru-ai/auv";
    changelog = "https://github.com/moeru-ai/auv/releases/tag/v${source.version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ xyenon ];
    mainProgram = "auv";
    platforms = source.platforms;
  };
}
