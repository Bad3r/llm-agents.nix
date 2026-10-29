{
  lib,
  buildGoModule,
  go_1_26,
  fetchFromGitHub,
  git,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
  mkUpdater,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
in
buildGoModule.override { go = go_1_26; } {
  pname = "open-code-review";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "alibaba";
    repo = "open-code-review";
    tag = "v${version}";
    inherit hash;
  };

  subPackages = [ "cmd/opencodereview" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=v${version}"
  ];

  # go.mod pins a newer patch release than nixpkgs' go_1_26.
  nativeBuildInputs = [ unpinGoModVersionHook ];

  postInstall = ''
    mv $out/bin/opencodereview $out/bin/ocr
  '';

  # The cmd tests shell out to git.
  nativeCheckInputs = [ git ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "version" ];

  passthru.category = "Code Review";
  passthru.updater = mkUpdater {
    kind = "github-source";
    purl = "pkg:github/alibaba/open-code-review";
    depHashKey = "vendorHash";
  };

  meta = with lib; {
    description = "AI-powered code review CLI";
    homepage = "https://github.com/alibaba/open-code-review";
    changelog = "https://github.com/alibaba/open-code-review/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "ocr";
    maintainers = with maintainers; [ fridh ];
    platforms = platforms.unix;
  };
}
