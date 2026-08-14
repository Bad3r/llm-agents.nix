# fetchurl on the builtin:fetchurl builder: a lone leaf derivation, no nixpkgs
# fetchurl wrapper or stdenv thunk graph. Same output path as pkgs.fetchurl
# for a given url + hash.
#
# Args are closed on purpose. bun2nix passes only { url, hash }, and the
# builtin serves nothing else (no unpack, auth, or curl opts), so anything
# extra fails loudly instead of being silently dropped.
{
  url,
  hash,
}:
derivation {
  inherit url;
  name = baseNameOf url;
  builder = "builtin:fetchurl";
  system = "builtin";
  urls = [ url ];
  outputHash = hash;
  outputHashMode = "flat";
  outputHashAlgo = null;
  preferLocalBuild = true;
  unpack = false;
  executable = false;
}
