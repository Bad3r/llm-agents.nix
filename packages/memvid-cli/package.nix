{
  lib,
  flake,
  stdenv,
  mkUpdater,
  platformSource,
  makeWrapper,
  formatelf,
  libx11,
  libxext,
  libxi,
  libxrender,
  libxtst,
  openssl,
  zlib,
  alsa-lib,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    };
    urlTemplate = "https://registry.npmjs.org/@memvid/cli-{platform}/-/cli-{platform}-{version}.tgz";
  };
in
stdenv.mkDerivation {
  pname = "memvid-cli";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = [
    formatelf
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    libx11
    libxext
    libxi
    libxrender
    libxtst
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    install -d $out/libexec/memvid-cli
    cp -R . $out/libexec/memvid-cli/
    chmod -R u+w $out/libexec/memvid-cli
    chmod 755 $out/libexec/memvid-cli/memvid

    makeWrapper $out/libexec/memvid-cli/memvid $out/bin/memvid \
      --prefix LD_LIBRARY_PATH : "$out/libexec/memvid-cli"

    runHook postInstall
  '';

  doInstallCheck = true;

  # No versionCheckHook: --version prints the bundled memvid-core version,
  # not the npm package version.
  installCheckPhase = ''
    runHook preInstallCheck

    tmp_home=$(mktemp -d)
    tmp_cache=$(mktemp -d)
    HOME="$tmp_home" XDG_CACHE_HOME="$tmp_cache" $out/bin/memvid --help > /dev/null

    runHook postInstallCheck
  '';

  passthru.category = "Memory & Code Intelligence";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "npm";
        package = "memvid-cli";
      };
    }
  );

  meta = with lib; {
    description = "AI memory CLI - crash-safe, single-file storage with semantic search";
    homepage = "https://memvid.com";
    changelog = "https://github.com/memvid/memvid/releases";
    license = licenses.asl20;
    # CLI is closed-source; upstream repo only contains the memvid-core library.
    sourceProvenance = with sourceTypes; [
      binaryNativeCode
    ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "memvid";
    inherit (source) platforms;
  };
}
