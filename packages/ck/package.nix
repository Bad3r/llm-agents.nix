{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  onnxruntime,
  stdenv,
  darwinMinVersionHook,
}:
rustPlatform.buildRustPackage rec {
  pname = "ck";
  version = "0.7.11";

  src = fetchFromGitHub {
    owner = "BeaconBay";
    repo = "ck";
    tag = version;
    hash = "sha256-YZ5zswjTvst6Ee5arJPKzz9BDIIXf/pHuQ6QB+qZ9kc=";
  };

  cargoHash = "sha256-sv7wTFN5eA7HWOE+syDGLtwcV/pvUmqyO8Cb0n5ldgE=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    onnxruntime
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    (darwinMinVersionHook "11.0")
  ];

  cargoBuildFlags = [ "--package=ck-search" ];

  # Tests require onnxruntime at runtime via @rpath
  doCheck = false;

  env = {
    # Use system onnxruntime instead of downloading binaries
    ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
  };

  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    install_name_tool -add_rpath "${lib.getLib onnxruntime}/lib" $out/bin/ck
  '';

  passthru.category = "Memory & Code Intelligence";

  meta = with lib; {
    description = "Local first semantic and hybrid BM25 grep / search tool for use by AI and humans!";
    homepage = "https://github.com/BeaconBay/ck";
    changelog = "https://github.com/BeaconBay/ck/releases/tag/${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "ck";
  };
}
