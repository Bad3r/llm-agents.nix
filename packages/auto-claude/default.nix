{
  pkgs,
  perSystem,
  ...
}:
pkgs.lib.warnOnInstantiate "'auto-claude' has been renamed to 'aperant'. Please update your references." perSystem.self.aperant
// {
  passthru.hideFromDocs = true;
}
