{
  lib,
  pkgs,
  flake,
  fetchFromGitHub,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "lambda-symbolics";
    repo = "autolith";
    tag = "v${version}";
    inherit (versionData) hash;
  };

  # Vendored copy of upstream's nix/package.nix, refreshed by update.py.
  upstream = import ./upstream-package.nix { inherit pkgs src; };
in
upstream.overrideAttrs (old: {
  name = "autolith-${version}";

  passthru = old.passthru // {
    category = "AI Assistants";
  };

  meta = old.meta // {
    description = "Live, self-modifying Common Lisp AI agent";
    homepage = "https://github.com/lambda-symbolics/autolith";
    changelog = "https://github.com/lambda-symbolics/autolith/releases/tag/v${version}";
    license = lib.licenses.isc;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ luciusmagn ];
  };
})
