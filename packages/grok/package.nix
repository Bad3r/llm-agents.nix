{
  lib,
  flake,
  stdenv,
  platformSource,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pname = "grok";
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x86_64";
      aarch64-linux = "linux-aarch64";
      aarch64-darwin = "macos-aarch64";
    };
    url =
      { version, platform }:
      "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-${platform}";
  };
  inherit (source) version;
in
stdenv.mkDerivation {
  inherit pname version;

  inherit (source) src;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/libexec/grok/grok

    makeWrapper $out/libexec/grok/grok $out/libexec/grok/grok-launcher \
      --argv0 grok \
      --add-flags --no-auto-update

    makeWrapper $out/libexec/grok/grok $out/libexec/grok/agent-launcher \
      --argv0 agent \
      --add-flags --no-auto-update

    # bin → launcher on all platforms. A former Linux-only bubblewrap shim
    # faked /bin/{bash,zsh} for older Grok builds that hardcoded those paths
    # (#4912 / #4913). Current Grok resolves the shell via $SHELL / PATH, and
    # the outer userns broke host tools (OpenSSH ownership checks, etc.).
    # versionCheck already used the unwrapped launcher (#7158).
    install -d $out/bin
    ln -s $out/libexec/grok/grok-launcher $out/bin/grok
    ln -s $out/libexec/grok/agent-launcher $out/bin/agent

    runHook postInstall
  '';

  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/libexec/grok/grok-launcher";
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Grok Build, xAI's agentic coding tool";
    homepage = "https://x.ai";
    changelog = "https://x.ai";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "grok";
    platforms = source.platforms;
  };
}
