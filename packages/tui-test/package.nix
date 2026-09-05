{
  lib,
  stdenv,
  flake,
  formatelf,
  platformSource,
  versionCheckHook,
  mkUpdater,
}:

let
  # Prebuilt: building from source needs Zig for the vendored libghostty-vt.
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      aarch64-darwin = "aarch64-apple-darwin";
    };
    urlTemplate = "https://github.com/microsoft/tui-test/releases/download/{version}/tui-test-{platform}.tar.gz";
  };
in
stdenv.mkDerivation {
  pname = "tui-test";
  inherit (source) version src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ formatelf ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 tui-test $out/bin/tui-test
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "Utilities";
  passthru.updater = mkUpdater (
    source.updater
    // {
      # All releases with binaries are prereleases, /releases/latest skips them.
      versionSource = {
        type = "text";
        url = "https://api.github.com/repos/microsoft/tui-test/releases?per_page=1";
        regex = ''"tag_name": *"([^"]+)"'';
      };
    }
  );

  meta = {
    description = "Control, inspect, test, and record any TUI app or CLI in a headless terminal";
    homepage = "https://github.com/microsoft/tui-test";
    changelog = "https://github.com/microsoft/tui-test/releases/tag/${source.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ willenbug ];
    mainProgram = "tui-test";
    platforms = source.platforms;
  };
}
