{
  lib,
  flake,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  curl,
  jansson,
  versionCheckHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hax";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "OleksandrChekhovskyi";
    repo = "hax";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/eX2l+BtjcmKsFM/w353i9iUPV+GOp1ZGBU06phNQ2o=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    curl
    jansson
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Minimalist, terminal-native coding agent written in C";
    homepage = "https://usehax.dev";
    changelog = "https://github.com/OleksandrChekhovskyi/hax/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ vidhanio ];
    mainProgram = "hax";
    platforms = lib.platforms.unix;
  };
})
