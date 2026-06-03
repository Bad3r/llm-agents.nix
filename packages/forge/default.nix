{
  pkgs,
  perSystem,
  ...
}:
pkgs.lib.warnOnInstantiate "'forge' has been renamed to 'forgecode'. Please update your references." perSystem.self.forgecode
// {
  passthru.hideFromDocs = true;
}
