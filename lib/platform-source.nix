# Select the prebuilt release artifact for the host platform from a package's
# hashes.json. Returns both the build `src` and a matching `updater` fragment
# from the same urlTemplate + platform map, so build and updater never diverge
# (see scripts/updater/run.py, kind = "platform").
{ stdenv, fetchurlTemplate }:

{
  hashesFile, # { version, hashes.<system> }
  # nix system -> URL vars. String is shorthand for the {platform} var; an
  # attrset supplies arbitrary vars (e.g. { os = "linux"; cpu = "x86_64"; }).
  platforms,
  urlTemplate,
}:

let
  versionData = builtins.fromJSON (builtins.readFile hashesFile);
  inherit (versionData) version;
  system = stdenv.hostPlatform.system;
  srcFor =
    system:
    let
      entry = platforms.${system} or (throw "Unsupported system: ${system}");
      platformVars = if builtins.isAttrs entry then entry else { platform = entry; };
    in
    fetchurlTemplate {
      inherit urlTemplate;
      vars = {
        inherit version;
      }
      // platformVars;
      hash = versionData.hashes.${system};
    };
  darwinSystems = builtins.filter (s: builtins.match ".*-darwin" s != null) (
    builtins.attrNames platforms
  );
in
{
  inherit version;
  platforms = builtins.attrNames platforms;
  src = srcFor system;
  # The darwin artifacts, fetchable on any host, so codesignCheckHook can verify
  # their signatures from a Linux build too.
  darwinSrcs = map srcFor darwinSystems;
  # Ready-to-merge passthru.updater fragment; caller adds a versionSource.
  updater = {
    kind = "platform";
    inherit urlTemplate platforms;
  };
}
