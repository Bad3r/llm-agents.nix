# Select the prebuilt release artifact for the host platform, using the
# per-platform hashes that a package's update.py writes into hashes.json.
{ stdenv, fetchurl }:

{
  # Path to the package's hashes.json ({ version, hashes.<system> }).
  hashesFile,
  # Maps nix system to the platform-specific URL part; the value for the host
  # platform is passed to `url` as `platform`.
  platforms,
  # { version, platform }: URL of the artifact for that platform.
  url,
}:

let
  versionData = builtins.fromJSON (builtins.readFile hashesFile);
  inherit (versionData) version;
  system = stdenv.hostPlatform.system;
  platform = platforms.${system} or (throw "Unsupported system: ${system}");
in
{
  inherit version;
  platforms = builtins.attrNames platforms;
  src = fetchurl {
    url = url { inherit version platform; };
    hash = versionData.hashes.${system};
  };
}
