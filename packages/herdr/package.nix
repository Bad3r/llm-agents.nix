{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  callPackage,
  zig_0_15,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    binaryHashes
    ;

  # build.rs shells out to `zig build` to compile vendored libghostty-vt.
  # On Linux this works in the sandbox.  On Darwin zig's libc/SDK discovery
  # relies on xcrun + system libtool, which aren't available; integrating
  # that with the nixpkgs apple-sdk is a larger project, so use the upstream
  # release binaries on Darwin until then.
  fromSource = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "herdr";
    inherit version;

    src = fetchFromGitHub {
      owner = "ogulcancelik";
      repo = "herdr";
      tag = "v${version}";
      inherit hash;
    };

    inherit cargoHash;

    # Upstream ships ghostty's zon2nix-generated build.zig.zon.nix alongside
    # the vendored libghostty-vt sources; use it to pre-fetch the Zig package
    # cache so zig can build offline.
    zigDeps = callPackage "${finalAttrs.src}/vendor/libghostty-vt/build.zig.zon.nix" {
      name = "herdr-libghostty-vt-zig-deps";
      inherit zig_0_15;
    };

    nativeBuildInputs = [
      zig_0_15
    ];

    # zig's setup hook overrides buildPhase/installPhase with `zig build`,
    # but here zig is only invoked indirectly from build.rs.  Keep cargo's
    # phases.
    dontUseZigBuild = true;
    dontUseZigInstall = true;
    dontUseZigCheck = true;
    dontUseZigConfigure = true;

    # build.rs passes an explicit -Dtarget that zig treats as a cross target,
    # so build-time helper executables (uucode_build_tables) get linked against
    # the FHS dynamic loader path which doesn't exist in the sandbox.  Drop the
    # flag so zig uses the native target and picks up the wrapped libc paths,
    # but keep Zig's CPU baseline explicit to avoid build-host CPU features
    # leaking into the output.
    postPatch = ''
      substituteInPlace build.rs \
        --replace-fail '.arg("build")' '.arg("build")
            .arg("-Dcpu=baseline")' \
        --replace-fail '.arg(format!("-Dtarget={zig_target}"))' ""
    '';

    preBuild = ''
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"
      ln -s ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    '';

    # Tests spawn PTYs / interact with the terminal and don't work in the
    # sandbox.
    doCheck = false;

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      versionCheckHook
      versionCheckHomeHook
    ];

    passthru.category = "Workflow & Project Management";

    meta = commonMeta // {
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
      platforms = lib.platforms.linux;
    };
  });

  binaryAssetMap = {
    x86_64-darwin = "herdr-macos-x86_64";
    aarch64-darwin = "herdr-macos-aarch64";
  };

  fromBinary = stdenv.mkDerivation {
    pname = "herdr";
    inherit version;

    src = fetchurl {
      url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/${
        binaryAssetMap.${stdenv.hostPlatform.system}
      }";
      hash = binaryHashes.${stdenv.hostPlatform.system};
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/herdr
      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      versionCheckHook
      versionCheckHomeHook
    ];

    passthru.category = "Workflow & Project Management";

    meta = commonMeta // {
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = builtins.attrNames binaryAssetMap;
    };
  };

  commonMeta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/ogulcancelik/herdr/releases/tag/v${version}";
    license = lib.licenses.agpl3Plus;
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "herdr";
  };
in
if stdenv.hostPlatform.isDarwin then fromBinary else fromSource
