{
  pkgs,
  perSystem,
  ...
}:
pkgs.lib.warnOnInstantiate "'antigravity' has been renamed to 'antigravity-cli'. Please update your references." perSystem.self.antigravity-cli
// {
  passthru.hideFromDocs = true;
}
