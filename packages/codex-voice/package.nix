{
  lib,
  stdenv,
  codex,
}:
# The codex variant Bad3r/nixos hosts install and update-codex pushes to the
# bad3r-nixos cache. Voice builds only on Linux, so elsewhere the package is
# marked unavailable and builds without voice instead of failing evaluation.
(codex.override {
  withCodeMode = true;
  withVoice = stdenv.hostPlatform.isLinux;
}).overrideAttrs
  (old: {
    passthru = old.passthru // {
      hideFromDocs = true;
      skipUpdate = true;
    };
    meta = old.meta // {
      platforms = lib.platforms.linux;
    };
  })
