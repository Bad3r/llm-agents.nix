{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "jscpd";
  version = "5.2.1";

  src = fetchFromGitHub {
    owner = "kucherenko";
    repo = "jscpd";
    tag = "v${version}";
    hash = "sha256-HHHTuqw2XSJVMf1J/Nq2S1vGViTccP9RGYA4WhjuyOE=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-8nl5/5cJPs0GmjhHWuXj+EY8/0aEZmDJnRdd12/LzXI=";

  cargoBuildFlags = [
    "-p"
    "jscpd"
  ];

  # Workspace tests exercise fixtures outside the rust/ source root.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Code Review";

  meta = {
    description = "Copy/paste detector for programming source code";
    homepage = "https://jscpd.dev";
    changelog = "https://github.com/kucherenko/jscpd/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ mic92 ];
    mainProgram = "jscpd";
    platforms = lib.platforms.all;
  };
}
