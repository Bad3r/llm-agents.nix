{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  makeWrapper,
  pkg-config,
  shaderc,
  alsa-lib,
  onnxruntime,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
  openssl,
  xdotool,
  libcanberra-gtk3,
  wtype,
  dotool,
  dbus,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "tonguetyped";
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "cheerfulScumbag";
    repo = "tonguetyped";
    tag = "v${version}";
    hash = "sha256-6IvPDbMJyt+ZGkY8IJO56ac8wkRdNnu0YASK67ybFOA=";
  };

  cargoHash = "sha256-79+uC0EvrQ7ndGCngLzCI29Wp9taDZQPWcLZiuNC8HY=";

  nativeBuildInputs = [
    cmake
    makeWrapper
    pkg-config
    rustPlatform.bindgenHook
    shaderc
  ];

  buildInputs = [
    alsa-lib
    onnxruntime
    spirv-headers
    vulkan-headers
    vulkan-loader
    openssl
    xdotool
  ];

  buildFeatures = [ "gpu-vulkan" ];

  env = {
    CMAKE_POLICY_VERSION_MINIMUM = "3.5";
    ORT_LIB_LOCATION = "${onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
  };

  nativeCheckInputs = [ dbus ];

  # pty_ tests need a pty, which the sandbox lacks
  cargoTestFlags = [
    "--"
    "--skip"
    "pty_"
  ];

  postInstall = ''
    install -Dm644 data/tonguetyped.desktop \
      $out/share/applications/io.github.cheerfulScumbag.tonguetyped.desktop
  '';

  postFixup = ''
    wrapProgram $out/bin/tonguetyped \
      --prefix PATH : ${
        lib.makeBinPath [
          libcanberra-gtk3
          wtype
          dotool
        ]
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Voice & Transcription";

  meta = {
    description = "Local Linux dictation controlled from the terminal or a desktop-wide keyboard shortcut";
    homepage = "https://github.com/cheerfulScumbag/tonguetyped";
    changelog = "https://github.com/cheerfulScumbag/tonguetyped/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ cheerfulScumbag ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "tonguetyped";
  };
}
