{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "pdfvision";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "yamadashy";
    repo = "pdfvision";
    tag = "v${finalAttrs.version}";
    hash = "sha256-KdLuxKn+qfhoXN0hKHnA+DG0igGUOlwz+aZ7lQRXzW8=";
  };

  npmDepsHash = "sha256-vVUwY3iqeYF1JbKAnSj4Y9hOiPNuzoRWukccuCOAe5g=";
  makeCacheWritable = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  doInstallCheck = true;

  passthru.category = "Utilities";

  meta = {
    description = "Extract text, metadata, and page images from PDF files, designed for AI agents";
    homepage = "https://pdfvision.dev/";
    changelog = "https://github.com/yamadashy/pdfvision/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ryoppippi ];
    mainProgram = "pdfvision";
    platforms = lib.platforms.all;
  };
})
