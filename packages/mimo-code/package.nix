{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  unzip,
  wrapBuddy,
  fzf,
  ripgrep,
  versionCheckHook,
  versionCheckHomeHook,
  writeShellScriptBin,
  flake,
}:

let
  pname = "mimo-code";
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = {
      asset = "mimocode-linux-x64.tar.gz";
      isZip = false;
    };
    aarch64-linux = {
      asset = "mimocode-linux-arm64.tar.gz";
      isZip = false;
    };
    x86_64-darwin = {
      asset = "mimocode-darwin-x64.zip";
      isZip = true;
    };
    aarch64-darwin = {
      asset = "mimocode-darwin-arm64.zip";
      isZip = true;
    };
  };

  platform = stdenv.hostPlatform.system;
  platformInfo = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/XiaomiMiMo/MiMo-Code/releases/download/v${version}/${platformInfo.asset}";
    hash = hashes.${platform};
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals platformInfo.isZip [
    unzip
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    (writeShellScriptBin "sysctl" "echo 0")
  ];
  versionCheckKeepEnvironment = "PATH";

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  wrapBuddyExtraNeeded = lib.optionals stdenv.hostPlatform.isLinux [
    "libstdc++.so.6"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
  ''
  + lib.optionalString platformInfo.isZip ''
    unzip $src
  ''
  + lib.optionalString (!platformInfo.isZip) ''
    tar -xzf $src
  ''
  + ''
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 mimo $out/bin/mimo

    wrapProgram $out/bin/mimo \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          ripgrep
        ]
      }

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Open-source AI coding agent with cross-session memory";
    longDescription = ''
      MiMoCode is a terminal-native AI coding assistant based on OpenCode.
      It adds persistent memory, context management, subagent orchestration,
      goal-driven autonomous loops, and compose workflows.
    '';
    homepage = "https://github.com/XiaomiMiMo/MiMo-Code";
    changelog = "https://github.com/XiaomiMiMo/MiMo-Code/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ scotttrinh ];
    platforms = builtins.attrNames platformMap;
    mainProgram = "mimo";
  };
}
