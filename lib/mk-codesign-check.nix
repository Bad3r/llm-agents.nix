# Verify the Developer ID signature of prebuilt darwin artifacts in a derivation
# of their own. Keeping this out of the package means a Linux build of the
# package does not fetch the macOS artifacts (#10349).
{
  stdenvNoCC,
  codesignCheckHook,
  unzip,
  undmg,
}:

{
  name,
  teamId,
  srcs,
}:

stdenvNoCC.mkDerivation {
  name = "codesign-check-${name}";
  dontUnpack = true;
  # The hook unpacks archives with unpackFile.
  nativeBuildInputs = [
    unzip
    undmg
  ];
  installPhase = "mkdir $out";
  doInstallCheck = true;
  nativeInstallCheckInputs = [ codesignCheckHook ];
  codesignTeamId = teamId;
  codesignSources = srcs;
}
