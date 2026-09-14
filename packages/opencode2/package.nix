{
  lib,
  mkUpdater,
  stdenv,
  makeWrapper,
  wrapBuddy,
  ripgrep,
  platformSource,
  versionCheckHook,
  versionCheckHomeHook,
  flake,
}:

let
  # OpenCode 2 ships as platform-specific Bun executables on npm
  # (@opencode/cli-<platform>).
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://registry.npmjs.org/@opencode/cli-{platform}/-/cli-{platform}-{version}.tgz";
  };
in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit (source) version src;

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  wrapBuddyExtraNeeded = lib.optionals stdenv.hostPlatform.isLinux [ "libstdc++.so.6" ];

  dontBuild = true;
  # Bun-compiled executable; stripping corrupts the embedded payload.
  dontStrip = true;

  # Install only the executable; the tarball also contains ~49 MiB of source
  # maps that are not needed at runtime.
  installPhase = ''
    runHook preInstall

    # Upstream's binary is `opencode`; install as opencode2 so it can coexist
    # with the v1 `opencode` package.
    install -Dm755 bin/opencode $out/bin/opencode2
    wrapProgram $out/bin/opencode2 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "npm";
        package = "@opencode/cli";
        # No tag: the npm source defaults to `latest`, the stable 2.x line.
      };
    }
  );

  meta = {
    description = "OpenCode 2 CLI";
    longDescription = ''
      OpenCode 2 is OpenCode's next-generation CLI. The single
      executable includes the terminal interface and server, and can run with
      a private server, reuse a background service, or connect to a remote
      server.
    '';
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/commits/v2";
    downloadPage = "https://www.npmjs.com/package/@opencode/cli?activeTab=versions";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ iainlane ];
    mainProgram = "opencode2";
    platforms = source.platforms;
  };
}
