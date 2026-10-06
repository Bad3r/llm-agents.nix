{
  lib,
  flake,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "toon-format";
  version = "0.6.1";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-oeMhG8j8c078c1Gc0VQNTC+c+fV7pUw9DRiNDVVx6OY=";
  };

  cargoHash = "sha256-Juwju7TSY3RGzkbT1L1EbpTv+eRDODE+8JU1FSO72Q0=";

  cargoBuildFlags = [
    "--features"
    "cli"
  ];

  doCheck = false;

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Rust implementation of TOON - Token-Oriented Object Notation for LLM prompts";
    homepage = "https://github.com/toon-format/toon-rust";
    changelog = "https://github.com/toon-format/toon-rust/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ antono ];
    mainProgram = "toon";
    platforms = platforms.all;
  };
}
