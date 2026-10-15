{
  lib,
  rustPlatform,
  fetchFromGitHub,
  protobuf,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "funes";
  version = "1.9.0";

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "funes";
    tag = "v${finalAttrs.version}";
    hash = "sha256-zc3PNM1QpAGCbLcYrLmxsbGErrRN2Y5f1/GfYIo3Aow=";
  };

  cargoHash = "sha256-dOxkDqRkwJptpSrCzKBKR9/gmhDEV7XxZ6UuFi1ferE=";

  postPatch = ''
    # Release CI stamps the version on the tag; the tagged Cargo.toml still
    # carries the dev label, which `funes --version` then reports.
    sed -i -E 's/^version = "[^"]*"$/version = "${finalAttrs.version}"/' Cargo.toml

    # The vendored crates live in the build root, outside the unpacked source.
    patch -p1 -d "$NIX_BUILD_TOP/$(stripHash "$cargoDeps")/source-registry-0" < ${./drop-lance-avx512-vnni.patch}
  '';

  # lance's protobuf schemas are generated at build time
  nativeBuildInputs = [ protobuf ];

  # lance's suite is slow and wants network fixtures
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Memory & Code Intelligence";

  meta = with lib; {
    description = "Searchable memory of past AI agent sessions, exposed over MCP";
    homepage = "https://github.com/huggingface/funes";
    changelog = "https://github.com/huggingface/funes/releases/tag/v${finalAttrs.version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ happysalada ];
    mainProgram = "funes";
    platforms = platforms.unix;
  };
})
