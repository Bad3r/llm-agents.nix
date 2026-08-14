{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  libgit2,
  git,
  python3Packages,
  flake,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tuicr";
  version = "0.22.0";

  src = fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-MotMXx3YEdR7s3Bz3ZW5Lk733S65zLzl9Pu6jReO9Bw=";
  };

  cargoHash = "sha256-7qrRsZ7SFi1LB9wI7oiwmE58cI+240IgmU7Zyhi6MAg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libgit2
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    git
    python3Packages.pexpect
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    # tuicr has no --version flag; verify the binary runs and produces expected output
    python3 ${./check-tuicr.py} $out/bin/tuicr
    runHook postInstallCheck
  '';

  passthru.category = "Code Review";

  meta = {
    description = "Review AI-generated diffs like a GitHub pull request, right from your terminal";
    homepage = "https://github.com/agavra/tuicr";
    changelog = "https://github.com/agavra/tuicr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "tuicr";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    maintainers = with flake.lib.maintainers; [ ypares ];
  };
})
