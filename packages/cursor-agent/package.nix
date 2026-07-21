{
  lib,
  flake,
  stdenv,
  platformSource,
  makeWrapper,
  coreutils,
  wrapBuddy,
  zlib,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pname = "cursor-agent";
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux/x64";
      aarch64-linux = "linux/arm64";
      aarch64-darwin = "darwin/arm64";
    };
    url =
      { version, platform }:
      "https://downloads.cursor.com/lab/${version}/${platform}/agent-cli-package.tar.gz";
  };
in
stdenv.mkDerivation rec {
  inherit pname;
  inherit (source) version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  wrapBuddyExtraNeeded = [ "libz.so.1" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Copy the dist-package contents
    mkdir -p $out
    cp -r dist-package/* $out/

    # Ensure binaries are executable
    chmod +x $out/cursor-agent
    chmod +x $out/node
    chmod +x $out/rg

    # Create a wrapper in bin directory
    mkdir -p $out/bin
    makeWrapper $out/cursor-agent $out/bin/cursor-agent \
      --prefix PATH : $out \
      --prefix PATH : ${coreutils}/bin

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Cursor Agent - CLI tool for Cursor AI code editor";
    homepage = "https://cursor.com/";
    changelog = "https://www.cursor.com/changelog";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = source.platforms;
    mainProgram = "cursor-agent";
  };
}
