{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "jscpd";
  version = "5.4.0";

  src = fetchFromGitHub {
    owner = "kucherenko";
    repo = "jscpd";
    tag = "v${version}";
    hash = "sha256-j4f1jYpj3N7hnPxm1cq8nOvi7bBgohu6nm2y0gt4e6s=";
  };

  sourceRoot = "${src.name}/rust";

  cargoHash = "sha256-wFmQjNspdmeWc9k1yhQbQ0xTyXlz92DaH+NZlJUJ7bA=";

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
