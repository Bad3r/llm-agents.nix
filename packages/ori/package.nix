{
  lib,
  flake,
  stdenv,
  mkUpdater,
  platformSource,
  wrapBuddy,
  makeBinaryWrapper,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://github.com/OpenRouterLabs/ori-releases/releases/download/cli-{version}/ori-{platform}";
  };
in
stdenv.mkDerivation {
  pname = "ori";
  inherit (source) version src;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/ori
    wrapProgram $out/bin/ori --set-default ORI_TELEMETRY 0
    runHook postInstall
  '';

  doInstallCheck = true;
  # ori prints the build hash with '+' (0.10.2+d7b2684) while the release tag
  # spells it with '-', so the stock versionCheckHook grep can never match.
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$(mktemp -d) $out/bin/ori --version | grep -F "${
      lib.replaceStrings [ "-" ] [ "+" ] source.version
    }"
    runHook postInstallCheck
  '';

  passthru.category = "AI Coding Agents";
  passthru.updater = mkUpdater (
    source.updater
    // {
      # Release tags are 'cli-<semver>-<hash>'; capture past the constant
      # prefix so stored versions stay numerically comparable (the raw tag
      # falls back to lexicographic ordering, which wedges at 0.10.9 -> 0.10.10
      # and permits downgrades).
      versionSource = {
        type = "text";
        url = "https://api.github.com/repos/OpenRouterLabs/ori-releases/releases/latest";
        regex = "\"tag_name\": *\"cli-([^\"]+)\"";
      };
    }
  );

  meta = with lib; {
    description = "OpenRouter CLI for managing agent environments across coding tools";
    homepage = "https://openrouter.ai/labs/ori";
    changelog = "https://github.com/OpenRouterLabs/ori-releases/releases/tag/cli-${source.version}";
    license = flake.lib.licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with flake.lib.maintainers; [ shzhng ];
    mainProgram = "ori";
    platforms = source.platforms;
  };
}
